||| DNSSD bridges to <dns_sd.h>, the C-language DNS Service Discovery API.
module DNSSD

%include C "dnssd_bridge.c"



public
data ResourceRecordType =
  A
  | AAAA


instance Show ResourceRecordType where
  show rrType =
    case rrType of
      A =>
        "A"

      AAAA =>
        "AAAA"


private
resourceRecordType : ResourceRecordType -> Int
resourceRecordType rrType =
  case rrType of
    A =>
      1

    AAAA =>
      28


private resourceRecordTypeFromInt : Int -> ResourceRecordType
resourceRecordTypeFromInt n =
  case n of
    28 =>
      AAAA

    _ =>
      A



public
data ResourceRecordClass = IN

instance Show ResourceRecordClass where
  show rrClass =
    case rrClass of
      IN => "IN"


private
resourceRecordClass : ResourceRecordClass -> Int
resourceRecordClass rrClass =
  case rrClass of
    IN =>
      1


private
resourceRecordClassFromInt : Int -> ResourceRecordClass
resourceRecordClassFromInt n =
  IN



public
record ResourceRecord where
  constructor mkResourceRecord
  fullname : String
  rrType : ResourceRecordType
  rrClass : ResourceRecordClass
  timeToLive : Int
  address : String


instance Show ResourceRecord where
  show rr =
    let fields = with List map (\f => f rr) [show . fullname, show . rrType, show . rrClass, show . timeToLive, show . address] in
    let fieldText = concat $ intersperse " " fields in
    "mkResourceRecord " ++ fieldText



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
resultRecordToResourceRecord resultRecord = do
  fullName <- recordFullname resultRecord
  rawRecordType <- recordRRType resultRecord
  rawRecordClass <- recordRRClass resultRecord
  timeToLive <- recordTTL resultRecord
  address <- recordAddress resultRecord
  let recordType = resourceRecordTypeFromInt rawRecordType
  let recordClass = resourceRecordClassFromInt rawRecordClass
  return $ mkResourceRecord fullName recordType recordClass timeToLive address
where
  recordFullname : Ptr -> IO String
  recordFullname resultRecord =
    foreign FFI_C
    "recordFullname"
    (Ptr -> IO String)
    resultRecord


  recordAddress : Ptr -> IO String
  recordAddress resultRecord =
    foreign FFI_C
    "recordAddress"
    (Ptr -> IO String)
    resultRecord


  recordRRType : Ptr -> IO Int
  recordRRType resultRecord =
    foreign FFI_C
    "recordRRType"
    (Ptr -> IO Int)
    resultRecord


  recordRRClass : Ptr -> IO Int
  recordRRClass resultRecord =
    foreign FFI_C
    "recordRRClass"
    (Ptr -> IO Int)
    resultRecord


  recordTTL : Ptr -> IO Int
  recordTTL resultRecord =
    foreign FFI_C
    "recordTTL"
    (Ptr -> IO Int)
    resultRecord



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
