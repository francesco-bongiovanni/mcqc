{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
module Classes.Typeful where
import Classes.Nameful
import CIR.Expr
import CIR.Decl
import Types.Context
import Data.MonoTraversable
import Data.Text (Text)
import qualified Data.Map  as M
import qualified Data.Text as T

-- This class is for instances with types
class Typeful a where
    -- Get all libraries needed by a
    getincludes  :: a -> [Text]
    -- Unify with a type (inference) with a Type context
    unify        :: Context CType -> CType -> a -> a
    -- Return the type
    gettype      :: a -> CType
    -- Add types to context
    addctx       :: Context CType -> a -> Context CType
    -- Get number of free types
    getMaxVaridx :: a -> Int

-- Has a type
instance Typeful CDecl where
    getincludes CDEmpty  {}     = []
    getincludes CDType   { .. } = getincludes _td
    getincludes CDFunc   { .. } = getincludes _fd ++ concatMap getincludes _fargs ++ getincludes _fbody
    getincludes CDStruct { .. } = concatMap getincludes _fields
    getincludes CDSeq    { .. } = getincludes _left ++ getincludes _right

    unify ctx t CDType   { .. } = CDType $ unify ctx t _td
    unify ctx t CDFunc   { .. } = CDFunc (unify ctx t _fd) _fargs $ unify ctx t _fbody
    unify ctx t CDStruct { .. } = CDStruct _sn (map (unify ctx t) _fields) _nfree
    unify ctx t CDSeq    { .. } = CDSeq (unify ctx t _left) (unify ctx t _right)
    unify _ _  a = a

    gettype CDType { .. } = gettype _td
    gettype CDFunc { .. } = map gettype _fargs --> _ty _fd
    gettype _             = CTAuto

    addctx ctx CDFunc { _fd = CDef { _nm = "match" } } = ctx
    addctx ctx d@CDFunc { .. } = mergeCtx ctx $ M.singleton (_nm _fd) (gettype d)
    addctx ctx CDType { _td = CDef { _ty = CTExpr { _tbase = "std::variant", ..  }, .. } }
        | freedom > 0 = mergeCtx ctx $ M.fromList . map exprmaker $ _tins
        | otherwise = mergeCtx ctx $ M.fromList . map basemaker $ _tins
        where freedom = maximum . map getMaxVaridx $ _tins
              exprmaker n = (getname n, CTExpr _nm [CTFree i | i <- [1..freedom]])
              basemaker n = (getname n, CTBase _nm)
    addctx ctx CDType { .. } = addctx ctx _td
    addctx ctx CDSeq  { .. } = ctx `addctx` _left `addctx` _right
    addctx ctx _ = ctx

    getMaxVaridx = getMaxVaridx . gettype

instance Typeful CDef where
    getincludes CDef  { .. } = getincludes _ty
    gettype CDef      { .. } = _ty
    unify ctx t CDef  { .. } = CDef _nm $ unify ctx t _ty
    addctx ctx CDef   { .. } = mergeCtx ctx $ M.singleton _nm _ty
    getMaxVaridx  = getMaxVaridx . gettype

instance Typeful CExpr where
    getincludes CExprSeq    { .. } = "proc" : getincludes _left ++ getincludes _right
    getincludes CExprCall   { _cd = CDef { _nm = "show" , ..}, .. } = "show" : getincludes _ty ++ concatMap getincludes _cparams
    getincludes CExprCall   { _cd = CDef { _nm = "gmatch" }, .. } = "variant" : concatMap getincludes _cparams
    getincludes CExprCall   { _cd = CDef { .. }, .. } = _nm : getincludes _ty ++ concatMap getincludes _cparams
    getincludes CExprStr    { .. } = ["String"]
    getincludes CExprNat    { .. } = ["nat"]
    getincludes CExprPair   { .. } = "pair" : getincludes _fst ++ getincludes _snd
    getincludes CExprStmt   { .. } = "proc" : getincludes _sd ++ getincludes _sbody
    getincludes CExprLambda { .. } = concatMap getincludes _lds ++ getincludes _lbody
    getincludes CExprBool   { .. } = ["bool"]
    getincludes CExprVar    { .. } = []

    gettype CExprSeq    { .. } = gettype . last . seqToList $ _right
    gettype CExprCall   { .. } = gettype _cd
    gettype CExprStr    { .. } = CTBase "string"
    gettype CExprNat    { .. } = CTBase "nat"
    gettype CExprPair   { .. } = CTExpr "pair" $ [gettype i | i <- [_fst, _snd]]
    gettype CExprStmt   { .. } = gettype _sd
    gettype CExprLambda { .. } = gettype _lbody
    gettype CExprBool   { .. } = CTBase "bool"
    gettype _ = CTAuto

    unify ctx t CExprCall { _cd = CDef { .. },  .. }
        -- Return preserves the type
        | _nm == "return"    = CExprCall newD $ map (unify ctx t) _cparams
        -- A match preserves the type if the lambdas return it (omit matched object)
        | _nm  == "match"    = CExprCall newD $ head _cparams:map (unify ctx t) (tail _cparams)
        -- Match with something from the context
        | otherwise = case ctx M.!? _nm of
              (Just CTFunc { .. }) -> CExprCall newD $ zipWith (unify ctx) _fins _cparams
              (_) -> CExprCall newD _cparams
        where newD = CDef _nm $ unify ctx t _ty
    -- Or explicit if it comes from the first rule handling return calls
    unify ctx t s@CExprSeq { .. } = listToSeq first <> retexpr
        where retexpr = unify ctx t . last . seqToList $ s
              first   = init . seqToList $ s
    unify ctx t o = omap (unify ctx t) o

    -- Cowardly refuse to add expression to global context
    addctx ctx _ = ctx

    -- Get max varidx by getting the type first
    getMaxVaridx = getMaxVaridx . gettype

instance Typeful CType where
    getincludes CTFunc { .. } = getincludes _fret ++ concatMap getincludes _fins
    getincludes CTExpr { .. } = T.toLower _tbase : concatMap getincludes _tins
    getincludes CTVar  { .. } = concatMap getincludes _vargs
    getincludes CTBase { .. } = [T.toLower _base]
    getincludes CTPtr  { .. } = getincludes _inner
    getincludes _             = []

    -- Unify the same type
    unify _ a b | a == b = b
    -- Type is better than auto-type
    unify _ t CTAuto = t
    unify _ CTAuto _ = CTAuto
    -- Function types
    unify c CTFunc { _fret = a, _fins = ina} CTFunc { _fret = b, _fins = inb}
        | length ina == length inb = zipWith (unify c) ina inb --> unify c a b
        | otherwise = error $ "Attempting to unify func types with different args" ++ show ina ++ " " ++ show inb
    -- Ignore Proc monad wrapped types
    unify c CTExpr { _tbase = "proc" , _tins = [a] } t = unify c a t
    unify c t CTExpr { _tbase = "proc" , _tins = [a] } = unify c t a
    -- Unify composite type expressions
    unify c CTExpr { _tbase = a , _tins = ina } CTExpr { _tbase = b , _tins = inb }
        | a == b && length ina == length inb = CTExpr a $ zipWith (unify c) ina inb
        | otherwise = error $ "Attempting to unify list types with different args" ++ show ina ++ " " ++ show inb
    -- Unify free parameters, here we're assuming Coq has already type-checked this
    unify _ CTFree { .. } t = t
    unify _ t CTFree { .. } = t
    -- Pointers go down, not up
    unify c CTPtr { .. } t = CTPtr $ unify c _inner t
    unify _ a b = error $ "Unsure how to unify " ++ show a ++ " " ++ show b

    -- Return the type itself
    gettype x = x

    -- addctx will not do anything without a name
    addctx ctx _ = ctx

    -- Return number of free variables
    getMaxVaridx t = foldl max 0 $ getVaridxs t
        where getVaridxs CTFree { .. } = [_idx]
              getVaridxs CTFunc { .. } = getVaridxs _fret ++ concatMap getVaridxs _fins
              getVaridxs CTExpr { .. } = concatMap getVaridxs _tins
              getVaridxs CTPtr  { .. } = getVaridxs _inner
              getVaridxs _ = [0]


