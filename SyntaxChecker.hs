module SyntaxChecker (isCoreModule, getModule) where

import           Language.Haskell.Exts


-- Disable module Name, default is Main even if you omit it
isCoreModuleName :: ModuleName -> Bool
isCoreModuleName (ModuleName mn)
    | mn == "Main" = True
    | otherwise = False

-- Disable all module pragma
isCoreModulePragma :: [ModulePragma] -> Bool
isCoreModulePragma [] = True
isCoreModulePragma _ = error "You can't use module pragma."


-- Disable all warning text
isCoreWarningText :: Maybe WarningText -> Bool
isCoreWarningText Nothing = True
isCoreWarningText _ = error "You can't use warning text."

-- Disable all export specification
isCoreExportSpec :: Maybe [ExportSpec] -> Bool
isCoreExportSpec Nothing = True
isCoreExportSpec (Just [EVar (UnQual (Ident n))]) | n == "main" = True
isCoreExportSpec _ = error "You can't use export specification."

-- Disable all import declaration
isCoreImportDecl ::  [ImportDecl] -> Bool
isCoreImportDecl [] = True
isCoreImportDecl _ = error "You can't use import declaration."

-- Check top-level declaration
-- FunBind example: f n = n + 1
-- d: the declaration, ns: the name defined in current file
isCoreDecl :: [Decl] -> Bool
isCoreDecl ds = all (isCoreDecl' names) ds
      where
        names = getNames ds
        isCoreDecl' ns (PatBind _ p t r b) =
            isCorePat ns p && isCoreType  t &&
            isCoreRhs ns r && isCoreBinds b
        isCoreDecl' _ _ = error "You can only use pattern binding."



isCorePat :: [String] -> Pat -> Bool
isCorePat ns (PVar n) = isCoreName ns n
isCorePat _  _ = error "You can't use pattern matching."

isCoreType :: Maybe Type -> Bool
isCoreType Nothing = True
isCoreType _ = error "You can't use type signature in pattern matching."

isCoreRhs :: [String] -> Rhs -> Bool
isCoreRhs ns (UnGuardedRhs e)= isCoreExp ns e
isCoreRhs _ (GuardedRhss _) = error "You can't use guard."


isCoreExp :: [String] -> Exp -> Bool
isCoreExp ns (Var qn) = isCoreQName ns qn
isCoreExp ns (Con qn) = isCoreQName ns qn
isCoreExp _ (Lit l) = isCoreLiterial l
isCoreExp ns (InfixApp e1 qop e2) = isCoreExp ns e1 && isCoreExp ns e2 && isCoreQOp qop
isCoreExp ns (App e1 e2) = isCoreExp ns e1 && isCoreExp ns e2
isCoreExp ns (NegApp e) = isCoreExp ns e
-- ns: names, vs: variables
isCoreExp ns (Lambda _ ps e) = all (isCorePat (ns ++ vs)) ps && isCoreExp (ns ++ vs) e
    where vs = map getNameFromPat ps
isCoreExp ns (List es) = all (isCoreExp ns) es
isCoreExp ns (Paren e) = isCoreExp ns e
isCoreExp ns (If e1 e2 e3) = isCoreExp ns e1 && isCoreExp ns e2 && isCoreExp ns e3
isCoreExp _ _ = error (
    "You can only use lambda expression," ++
    "parenthesis, list, if and operator defined in core-haskell." )

isCoreQOp :: QOp -> Bool
isCoreQOp (QVarOp qn) = isCoreQName [] qn
isCoreQOp (QConOp qn) = isCoreQName [] qn

isCoreBinds :: Binds -> Bool
isCoreBinds (BDecls []) = True
isCoreBinds (IPBinds []) = True
isCoreBinds _ = error "You can't use let or where clause"



{-
core function
-}

isCoreQName :: [String] -> QName -> Bool
isCoreQName _ (Qual _ _) = error "You can't import module"
isCoreQName qns (UnQual n) = isCoreName qns n
isCoreQName _ (Special s) = isCoreSpecialCon s

isCoreName :: [String] -> Name -> Bool
isCoreName ns (Ident s) = s `elem`
    ["div", "mod", "not", "head", "tail", "False", "True"] ++ ns
    -- H1-simple.pdf
    ++ ["null", "length", "elem"]
    -- H2-map_filter.pdf
    ++ ["map"]
    -- H3-foldr.pdf
    ++ ["foldr", "foldl", "and", "all", "any", "elem", "sum", "filter"]
    -- H4-ListUtils
    ++ ["drop", "take", "dropWhile", "zip", "zipWith"]
    -- H6-Accumulators
    ++ ["max", "min"]
    ||  error ("You can't use " ++ show s)
isCoreName ns (Symbol s) = s `elem`
    ["+", "-", "*", "&&", "||", "==", "/=", "<=", ">=", "<", ">"] ++ ns
    ||  error ("You can't use " ++ show s)

-- Get name from top level definitions
getNames :: [Decl] -> [String]
getNames = map getName
        where
        getName (PatBind _ p _ _ _) = getNameFromPat p
        getName _ = error "You can only use pattern binding"

getNameFromPat :: Pat -> String
getNameFromPat (PVar (Ident  n)) = n
getNameFromPat (PVar (Symbol n)) = n
getNameFromPat _ = error "You can't use pattern matching."

isCoreSpecialCon :: SpecialCon -> Bool
isCoreSpecialCon (Cons) = True
isCoreSpecialCon _ = error "You can't use () [] -> , #,# # #"

isCoreLiterial :: Literal -> Bool
isCoreLiterial (Char _) = True
isCoreLiterial (String _) = True
isCoreLiterial (Int _) = True
isCoreLiterial _ = error "You can only use Char String Int"


-- Check the whole module/file
isCoreModule :: Module -> Bool
isCoreModule (Module _ mn mp wt es im d) =
    isCoreModuleName  mn && isCoreModulePragma mp &&
    isCoreWarningText wt && isCoreExportSpec   es &&
    isCoreImportDecl  im && isCoreDecl         d

-- Check single statement whithin interpreter
isCoreStatement :: String -> Bool
isCoreStatement = undefined


getModule :: String -> IO Module
getModule mPath = do
    src <- readFile mPath
    --src <- readFile "./hello_world.hs"
    return . fromParseResult $ parseModule src

 --below just used for test the parse result of haskell-src-ext
printAlldecl :: Module -> IO()
printAlldecl (Module _ _ _ _ _ _ ds) = mapM_  print ds

main :: IO ()
main = do
  m <- getModule "Hello.hs"
  print m
  --printAlldecl m
  --print (isCoreModule m)
