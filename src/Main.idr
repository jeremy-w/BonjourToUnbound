{-
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
https://mozilla.org/MPL/2.0/.
-}

module Main

import DNSSD

PROGNAME : String
PROGNAME = "local_network_injector"

hostnamesFromArguments : List String -> Maybe (String, String)
hostnamesFromArguments arguments =
  case arguments of
    _ :: hostname :: bonjourHostname :: _ =>
      Just (hostname, bonjourHostname)

    _ =>
      Nothing



printUsage : IO ()
printUsage =
  putStrLn $ "usage: " ++ PROGNAME ++ " HOSTNAME BONJOUR_HOSTNAME\n"
    ++ "\n"
    ++ "Copy DNS-SD query results for BONJOUR_HOSTNAME \n"
    ++ "into Unbound's local data records for HOSTNAME.\n"
    ++ "Deletes local records for HOSTNAME if no DNS-SD results are found."


{-
Using lldb to watch for calls to DNS* functions when running
`dns-sd -q Hostname.local. A IN` shows it calls out to:

- DNSServiceQueryRecord: this is passed a callback
- DNSServiceSetDispatchQueue: tells the service to deliver callbacks to the target queue
- DNSServiceRefSockFD: this can be used to watch for readability in a select loop;
  this is called as part of SetDispatchQueue's implementation
- DNSServiceProcessResult: called on the DNSServiceRef to trigger callbacks
-}
bonjourQuery : String -> IO $ Either String (List DNSSD.ResourceRecord)
bonjourQuery hostname =
  DNSSD.serviceQueryRecord hostname DNSSD.A DNSSD.IN



unboundControl : List String -> IO $ Either String ()
unboundControl arguments = do
  let fullArguments = "/usr/local/sbin/unbound-control" :: arguments
  let command = concat $ intersperse " " fullArguments
  putStrLn $ "running: " ++ command
  process <- File.popen command File.Read
  output <- fread process
  -- XXX: Idris' pclose doesn't return status.
  -- Luckily, unbound-control writes "ok\n" on success.
  pclose process
  let result = if "ok" `isPrefixOf` output
    then Right ()
    else Left output
  return result

unboundRemove : String -> IO $ Either String ()
unboundRemove hostname =
  return $ Left $
    "unboundRemove " ++ hostname ++ ": not yet implemented"


resourceRecordToLocalData : DNSSD.ResourceRecord -> String
resourceRecordToLocalData resourceRecord = let
    fullname = fullname resourceRecord
    rrType = show $ rrType resourceRecord
    rrClass = show $ rrClass resourceRecord
    timeToLive = show $ timeToLive resourceRecord
    address = address resourceRecord
  in
    fullname ++ " " ++ timeToLive ++ " " ++ rrClass ++ " " ++ rrType ++ " " ++ address


unboundRegister : List DNSSD.ResourceRecord -> IO $ Either String ()
unboundRegister records = do
  let entries = map resourceRecordToLocalData records
  let quotedEntries = map (\entry => "'" ++ entry ++ "'") entries
  let argumentses = map (\entry => ["local_data", entry]) quotedEntries
  results <- for argumentses (\arguments => unboundControl arguments)
  let failures = lefts results
  let result = if isNil failures
    then Right ()
    -- The failure text already includes a final newline, so we don't need to add any.
    else Left $ concat $ failures
  return result


rewriteFullnameToIn : String -> List DNSSD.ResourceRecord -> List DNSSD.ResourceRecord
rewriteFullnameToIn toName inRecords =
  map (record { fullname = toName }) inRecords



updateRecordsForHostnamePerBonjourName : String -> String -> IO $ Either String ()
updateRecordsForHostnamePerBonjourName hostname bonjourName = do
  result <- bonjourQuery bonjourName
  case result of
    Left error =>
      return $ Left error

    Right records =>
      case records of
        [] =>
          unboundRemove hostname

        _ =>
          unboundRegister $ rewriteFullnameToIn hostname records


reportError : String -> IO ()
reportError message =
  putStrLn $
    PROGNAME ++ ": " ++ message


main : IO ()
main = do
  arguments <- getArgs
  let maybeHostnames = hostnamesFromArguments arguments
  case maybeHostnames of
    Nothing => do
      reportError "missing required arguments: HOSTNAME or BONJOUR_HOSTNAME"
      printUsage

    Just (hostname, bonjourHostname) => do
      result <- updateRecordsForHostnamePerBonjourName hostname bonjourHostname
      case result of
        Left error =>
          reportError error

        Right _ =>
          return ()
