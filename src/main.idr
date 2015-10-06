module Main

PROGNAME : String
PROGNAME = "local_network_injector"

hostnameFromArguments : List String -> Maybe String
hostnameFromArguments arguments =
  case arguments of
    _ :: hostname :: _ =>
      Just hostname

    _ =>
      Nothing



printUsage : IO ()
printUsage =
  putStrLn $ "usage: " ++ PROGNAME ++ " HOSTNAME\n"
    ++ "\n"
    ++ "    Copy DNS-SD query results for HOSTNAME into Unbound's local data records."


DNSRecord : Type
DNSRecord =
  String

bonjourQuery : String -> Either String (Maybe $ List $ DNSRecord)
bonjourQuery hostname =
  Left "undefined"

unboundRemove : String -> Either String ()
unboundRemove hostname =
  Left "undefined"

unboundRegister : List DNSRecord -> Either String ()
unboundRegister records =
  Left "undefined"



updateRecordsFor : String -> Either String ()
updateRecordsFor hostname =
  let result = bonjourQuery hostname in
  case result of
    Left error =>
      Left error

    Right maybeRecords =>
      case maybeRecords of
        Nothing =>
          unboundRemove hostname

        Just records =>
          unboundRegister records


reportError : String -> IO ()
reportError message =
  putStrLn $
    PROGNAME ++ ": " ++ message


main : IO ()
main = do
  arguments <- getArgs
  let maybeHostname = hostnameFromArguments arguments
  case maybeHostname of
    Nothing => do
      reportError "missing required argument HOSTNAME"
      printUsage

    Just hostname =>
      case updateRecordsFor hostname of
        Left error =>
          reportError error

        Right _ =>
          return ()
