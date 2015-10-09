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
queryResultResourceRecords : Ptr -> IO $ List Ptr
queryResultResourceRecords queryResult = do
    head <- queryResultRecordList queryResult
    list <- collect walkNextPointer head
    return list
  where
    {-
    ||| collect is basically unfoldrM.
    |||
    ||| Melvar notes that unfoldr doesn't really belong in the Idris stdlib
    ||| because it's not total. They suggest looking at Data.CoList in contrib instead,
    ||| which represents possibly-infinite lists.
    |||
    ||| It's not clear to me how Data.CoList would differ from Prelude.Stream, though.
    -}
    collect : (b -> IO $ Maybe (a, b)) -> b -> IO $ List a
    collect generate seed =
      collect' [] seed
      where
        collect' : List a -> b -> IO $ List a
        collect' accumulator seed = do
          maybeNext <- generate seed
          case maybeNext of
            Nothing =>
              return $ reverse accumulator

            Just (output, nextSeed) =>
              collect' (output :: accumulator) nextSeed


    resourceNext : Ptr -> IO Ptr
    resourceNext resourceRecordPtr =
      foreign FFI_C
      "recordNext"
      (Ptr -> IO Ptr)
      resourceRecordPtr


    walkNextPointer : Ptr -> IO $ Maybe (Ptr, Ptr)
    walkNextPointer resourceRecordPtr = do
      isNullPtr <- Strings.nullPtr resourceRecordPtr
      if isNullPtr
      then return Nothing
      else do
        next <- resourceNext resourceRecordPtr
        return $ Just (resourceRecordPtr, next)


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
    resultRecords <- queryResultResourceRecords queryResult
    records <- sequence $ map resultRecordToResourceRecord resultRecords
    return $ Right records
