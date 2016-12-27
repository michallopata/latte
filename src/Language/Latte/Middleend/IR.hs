{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TemplateHaskell #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing #-}
module Language.Latte.Middleend.IR where

import Control.Lens
import qualified Data.ByteString.Char8 as BS
import Data.String
import qualified Language.Latte.Frontend.AST as Frontend
import Text.PrettyPrint
import Text.PrettyPrint.HughesPJClass

newtype UniqueId = UniqueId { getUniqueId :: Int }
    deriving (Eq, Ord, Show)

newtype Ident = Ident { getIdent :: BS.ByteString }
    deriving (Eq, Ord, Show, IsString)

data Operand
    = OperandNamed !Name
    | OperandInt !Int
    deriving Show

data Name = Name
    { _nameUnique :: {-# UNPACK #-} !UniqueId
    , _nameHuman :: !(Maybe Ident)
    }
    deriving (Eq, Ord, Show)

data Memory
    = MemoryLocal {-# UNPACK #-} !Int
    | MemoryThis
    | MemoryPointer !Operand
    | MemoryField !Memory {-# UNPACK #-} !Int
    | MemoryOffset !Memory !Operand !Size
    | MemoryGlobal !Ident
    deriving Show

data Size = Size8 | Size32 | Size64 | Size0 | SizePtr
    deriving Show

data InstrPayload
    = ILoad !Load
    | IStore !Store
    | IBinOp !BinOp
    | IUnOp !UnOp
    | IGetAddr !GetAddr
    | ICall !Call
    | IIntristic !Intristic
    | IIncDec !IncDec
    deriving Show

data Instruction = Instruction
    { _instrResult :: !Name
    , _instrPayload :: !InstrPayload
    , _instrLocation :: !(Maybe Frontend.LocRange)
    , _instrMetadata :: [InstrMetadata]
    }
    deriving Show

data InstrMetadata
    = InstrComment Doc
    deriving Show

data Block = Block
    { _blockName :: !Name
    , _blockPhi :: [PhiNode]
    , _blockBody :: [Instruction]
    , _blockEnd :: !BlockEnd
    }
    deriving Show

data PhiNode = PhiNode
    { _phiName :: !Name
    , _phiBranches :: [PhiBranch]
    }
    deriving Show

data PhiBranch = PhiBranch
    { _phiFrom :: !Name
    , _phiValue :: !Operand
    }
    deriving Show

data BlockEnd
    = BlockEndBranch !Name
    | BlockEndBranchCond !Operand !Name !Name
    | BlockEndReturn !Operand
    | BlockEndReturnVoid
    | BlockEndNone
    deriving Show

data Load = Load
    { _loadFrom :: !Memory
    , _loadSize :: !Size
    }
    deriving Show

data Store = Store
    { _storeTo :: !Memory
    , _storeSize :: !Size
    , _storeValue :: !Operand
    }
    deriving Show

data BinOp = BinOp
    { _binOpLhs :: !Operand
    , _binOpOp ::  !BinOperator
    , _binOpRhs :: !Operand
    }
    deriving Show

data UnOp = UnOp
    { _unOpOp :: !UnOperator
    , _unOpArg :: !Operand
    }
    deriving Show

newtype GetAddr = GetAddr { _getAddrMem :: Memory }
    deriving Show

data Call = Call
    { _callDest :: !CallDest
    , _callArgs :: [Operand]
    }
    deriving Show

data CallDest
    = CallDestFunction !Ident
    | CallDestVirtual !Memory !Int
    deriving Show

data BinOperator
    = BinOpPlus
    | BinOpMinus
    | BinOpTimes
    | BinOpDivide
    | BinOpModulo
    | BinOpLess
    | BinOpLessEqual
    | BinOpGreater
    | BinOpGreaterEqual
    | BinOpEqual
    | BinOpNotEqual
    | BinOpAnd
    | BinOpOr
    deriving Show

data UnOperator
    = UnOpNeg
    | UnOpNot
    deriving Show

data Intristic
    = IntristicAlloc {-# UNPACK #-} !Int !ObjectType
    deriving Show

data ObjectType
    = ObjectInt
    | ObjectLong
    | ObjectBoolean
    | ObjectString
    | ObjectPrimArray
    | ObjectArray
    | ObjectClass !Ident
    deriving Show

data IncDec
    = Inc { _incDecMemory :: !Memory, _incDecSize :: !Size }
    | Dec { _incDecMemory :: !Memory, _incDecSize :: !Size }
    deriving Show

makeClassy ''Name
makeLenses ''Load
makeLenses ''Store
makeLenses ''BinOp
makeLenses ''UnOp
makeLenses ''GetAddr
makeLenses ''Call
makeLenses ''Instruction
makeLenses ''Block
makeLenses ''IncDec

instance HasName Block where
    name = blockName

instance HasName Instruction where
    name = instrResult

instance Pretty Ident where
    pPrint (Ident ident) = text (BS.unpack ident)

instance Pretty UniqueId where
    pPrint (UniqueId ident) = int ident

instance Pretty Operand where
    pPrint (OperandNamed n) = pPrint n
    pPrint (OperandInt i) = int i

instance Pretty Name where
    pPrint (Name i Nothing) = char '%' <> pPrint i
    pPrint (Name i (Just n)) = char '%' <> pPrint n <> char '.' <> pPrint i

instance Pretty Memory where
    pPrint (MemoryLocal i) = braces (int i)
    pPrint MemoryThis = "this"
    pPrint (MemoryPointer ptr) = "deref" <> pPrint ptr
    pPrint (MemoryField mem i) = pPrint mem <> char '.' <> int i
    pPrint (MemoryOffset mem i sz) = pPrint mem <> brackets (pPrint i <+> "*" <+> pPrint sz)
    pPrint (MemoryGlobal i) = "global" <+> pPrint i

instance Pretty Size where
    pPrint Size8 = "8 bits"
    pPrint Size32 = "32 bits"
    pPrint Size64 = "64 bits"
    pPrint Size0 = "0 bits"
    pPrint SizePtr = "word"

instance Pretty Load where
    pPrint load = hsep
        [ "load"
        , pPrint (load ^. loadSize)
        , "from"
        , pPrint (load ^. loadFrom)
        ]

instance Pretty Store where
    pPrint store = hsep
        [ "store"
        , pPrint (store ^. storeSize)
        , "value"
        , pPrint (store ^. storeValue)
        , "to"
        , pPrint (store ^. storeTo)
        ]

instance Pretty BinOp where
    pPrint binOp = hsep
        [ pPrint (binOp ^. binOpLhs)
        , pPrint (binOp ^. binOpOp)
        , pPrint (binOp ^. binOpRhs)
        ]

instance Pretty BinOperator where
    pPrint BinOpPlus = "+"
    pPrint BinOpMinus = "-"
    pPrint BinOpTimes = "*"
    pPrint BinOpDivide = "/"
    pPrint BinOpModulo = "%"
    pPrint BinOpLess = "<"
    pPrint BinOpLessEqual = "<="
    pPrint BinOpGreater = ">"
    pPrint BinOpGreaterEqual = ">="
    pPrint BinOpEqual = "=="
    pPrint BinOpNotEqual = "!="
    pPrint BinOpAnd = "&&"
    pPrint BinOpOr = "||"

instance Pretty UnOp where
    pPrint unOp = hsep
        [ pPrint (unOp ^. unOpOp)
        , pPrint (unOp ^. unOpArg)
        ]

instance Pretty UnOperator where
    pPrint UnOpNeg = "-"
    pPrint UnOpNot = "!"

instance Pretty GetAddr where
    pPrint getAddr = hsep
        [ "getAddr"
        , pPrint (getAddr ^. getAddrMem)
        ]

instance Pretty Call where
    pPrint call = "call" <+> pPrint (call ^. callDest) <> parens (sep . punctuate comma $ map pPrint (call ^. callArgs))

instance Pretty CallDest where
    pPrint (CallDestFunction fun) = pPrint fun
    pPrint (CallDestVirtual memory i) = "virtual" <+> pPrint memory <> colon <> int i

instance Pretty Intristic where
    pPrint (IntristicAlloc size ty) = "alloc" <+> int size <+> "bytes of" <+> pPrint ty

instance Pretty ObjectType where
    pPrint ObjectInt = "int"
    pPrint ObjectLong = "long"
    pPrint ObjectBoolean = "boolean"
    pPrint ObjectString = "string"
    pPrint ObjectPrimArray = "primArray"
    pPrint ObjectArray = "array"
    pPrint (ObjectClass cls) = "class" <+> pPrint cls

instance Pretty InstrPayload where
    pPrint (ILoad load) = pPrint load
    pPrint (IStore store) = pPrint store
    pPrint (IBinOp binOp) = pPrint binOp
    pPrint (IUnOp unOp) = pPrint unOp
    pPrint (IGetAddr getAddr) = pPrint getAddr
    pPrint (ICall call) = pPrint call
    pPrint (IIntristic intristic) = pPrint intristic
    pPrint (IIncDec incdec) = pPrint incdec

instance Pretty Instruction where
    pPrint instr = hsep
        [ pPrint (instr ^. instrResult)
        , "="
        , pPrint (instr ^. instrPayload)
        , ";"
        , maybe empty pPrint (instr ^. instrLocation)
        , "#"
        , hsep . punctuate semi $ map pPrint (instr ^. instrMetadata)
        ]

instance Pretty InstrMetadata where
    pPrint (InstrComment comment) = comment

instance Pretty Block where
    pPrint blk = hang (pPrint (blk ^. name)) 4 $ vcat [phis, body, end]
      where
        phis = vcat . map pPrint $ blk ^. blockPhi
        body = vcat . map pPrint $ blk ^. blockBody
        end = pPrint (blk ^. blockEnd)

instance Pretty BlockEnd where
    pPrint (BlockEndBranch target) = "branch to" <+> pPrint target
    pPrint (BlockEndBranchCond cond targetTrue targetFalse) = sep
        [ "branch to: if"
        ,  pPrint cond
        , "then"
        , pPrint targetTrue
        , "else"
        , pPrint targetFalse
        ]
    pPrint (BlockEndReturn ret) = "return" <+> pPrint ret
    pPrint BlockEndReturnVoid = "return"
    pPrint BlockEndNone = "must be unreachable"

instance Pretty IncDec where
    pPrint (Inc mem sz) = sep
        [ "increment"
        , pPrint sz
        , "at"
        , pPrint mem]
    pPrint (Dec mem sz) = sep
        [ "decrement"
        , pPrint sz
        , "at"
        , pPrint mem]

instance Pretty PhiNode where
    pPrint (PhiNode name branches) = pPrint name <+> "= phi" <+> sep (punctuate comma $ map pPrint branches)

instance Pretty PhiBranch where
    pPrint (PhiBranch from value) = pPrint from <+> "if from" <+> pPrint value