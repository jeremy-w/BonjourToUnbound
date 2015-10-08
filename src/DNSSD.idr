||| DNSSD bridges to <dns_sd.h>, the C-language DNS Service Discovery API.
module DNSSD

%include C "dnssd_bridge.c"

public
data ResourceRecordType =
  A
  | AAAA

private
resourceRecordType : ResourceRecordType -> Int
resourceRecordType rrType =
  case rrType of
    A =>
      1

    AAAA =>
      28

public
data ResourceRecordClass = IN

private
resourceRecordClass : ResourceRecordClass -> Int
resourceRecordClass rrClass =
  case rrClass of
    IN =>
      1

private
kDNSServiceFlagsTimeout : Int
kDNSServiceFlagsTimeout            = 0x10000

private
kDNSServiceFlagsValidate : Int
kDNSServiceFlagsValidate               = 0x200000

public
record ResourceRecord where
  constructor mkResourceRecord
  fullname : String
  rrType : ResourceRecordType
  rrClass : ResourceRecordClass
  timeToLive : Int


private
synchronouslyQueryRecord : String -> ResourceRecordType -> ResourceRecordClass
  -> IO Ptr
synchronouslyQueryRecord fullName rrType rrClass =
  foreign FFI_C
  "synchronouslyQueryRecord"
  (String -> Int -> Int -> IO Ptr)
  fullName (resourceRecordType rrType) (resourceRecordClass rrClass)


private
queryResultIsError : Ptr -> IO Bool
queryResultIsError result = do
  intVal <- foreign FFI_C
    "queryResultIsError"
    (Ptr -> IO Int)
    result
  return $ intVal /= 0


private
queryResultError : Ptr -> IO Int
queryResultError result =
  foreign FFI_C
  "queryResultError"
  (Ptr -> IO Int)
  result


private
queryResultRecordList : Ptr -> IO Ptr
queryResultRecordList result =
  foreign FFI_C
  "queryResultRecordList"
  (Ptr -> IO Ptr)
  result


private
resultRecordToResourceRecord : Ptr -> IO $ ResourceRecord
resultRecordToResourceRecord headResult =
  return $ mkResourceRecord "WIP" A IN 0


private
extractResultList : Ptr -> IO $ List Ptr
extractResultList queryResult =
  return $ List.Nil


||| Synchronously queries for a record on all interfaces.
abstract
serviceQueryRecord : String -> ResourceRecordType -> ResourceRecordClass
  -> IO $ Either String (List ResourceRecord)
serviceQueryRecord fullName rrType rrClass = do
  queryResult <- synchronouslyQueryRecord fullName rrType rrClass
  isError <- queryResultIsError queryResult
  if isError
  then return $ Left $ "error " ++ show !(queryResultError queryResult)
  else do
    results <- extractResultList queryResult
    records <- sequence $ map resultRecordToResourceRecord results
    return $ Right records
