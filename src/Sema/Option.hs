{-# LANGUAGE OverloadedStrings  #-}
{-# LANGUAGE RecordWildCards  #-}
module Sema.Option where
import Common.Flatten
import CIR.Expr
import Data.Maybe

-- Option semantics
optionSemantics :: CExpr -> CExpr
optionSemantics CExprCall { _fname = "Datatypes.Some", _fparams = [a] } = CExprOption CTUndef (Just a)
optionSemantics CExprCall { _fname = "Datatypes.None", _fparams = [] }  = CExprOption CTUndef Nothing
optionSemantics c@CExprCall { .. }
    | _fname == "Datatypes.Some" ||
      _fname == "Datatypes.None" = error $ "Option constructors with the wrong number of args" ++ show c
optionSemantics other = descend optionSemantics other
