{-
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
https://mozilla.org/MPL/2.0/.
-}

module Main

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


DNSRecord : Type
DNSRecord =
  String

{-
Using lldb to watch for calls to DNS* functions when running
`dns-sd -q Hostname.local. A IN` shows it calls out to:

- DNSServiceQueryRecord: this is passed a callback
- DNSServiceSetDispatchQueue: tells the service to deliver callbacks to the target queue
- DNSServiceRefSockFD: this can be used to watch for readability in a select loop;
  this is called as part of SetDispatchQueue's implementation
- DNSServiceProcessResult: called on the DNSServiceRef to trigger callbacks
-}
bonjourQuery : String -> Either String (Maybe $ List $ DNSRecord)
bonjourQuery hostname =
  Left "undefined"

unboundRemove : String -> Either String ()
unboundRemove hostname =
  Left "undefined"

unboundRegister : List DNSRecord -> Either String ()
unboundRegister records =
  Left "undefined"

rewriteHostnameFromToIn : String -> String -> List String -> List DNSRecord
rewriteHostnameFromToIn fromName toName inRecords =
  ["unimplemented"]



updateRecordsForHostnamePerBonjourName : String -> String -> Either String ()
updateRecordsForHostnamePerBonjourName hostname bonjourName =
  let result = bonjourQuery bonjourName in
  case result of
    Left error =>
      Left error

    Right maybeRecords =>
      case maybeRecords of
        Nothing =>
          unboundRemove hostname

        Just records =>
          unboundRegister $ rewriteHostnameFromToIn bonjourName hostname records


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

    Just (hostname, bonjourHostname) =>
      case updateRecordsForHostnamePerBonjourName hostname bonjourHostname of
        Left error =>
          reportError error

        Right _ =>
          return ()
