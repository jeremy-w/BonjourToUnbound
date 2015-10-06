||| DNSSD bridges to <dns_sd.h>, the C-language DNS Service Discovery API.
module DNSSD

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

||| Synchronously queries for a record on all interfaces.
abstract
serviceQueryRecord : String -> ResourceRecordType -> ResourceRecordClass -> Either String (List ResourceRecord)
serviceQueryRecord fullName rrType rrClass = Right []
