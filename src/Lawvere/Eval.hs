module Lawvere.Eval where

import Data.Bifunctor
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import Lawvere.Core
import Lawvere.Decl
import Lawvere.Disp
import Lawvere.Expr
import Lawvere.Scalar
import Prettyprinter
import Protolude

data Val
  = Rec (Map LcIdent Val)
  | Tag LcIdent Val
  | Sca Sca
  | VFun (Val -> IO Val)

instance Disp Val where
  disp = \case
    Sca s -> disp s
    Rec r -> commaBrace (Map.toList r)
    Tag t v -> disp t <> parens (disp v)
    VFun _ -> "<unshowable>"

type Tops = Map LcIdent (Val -> IO Val)

evalAr :: Tops -> Expr -> Val -> IO Val
evalAr tops = \case
  -- Id -> pure
  EConst e -> const (pure (VFun (evalAr tops e)))
  Top i -> \v -> case Map.lookup i tops of
    Just f -> f v
    Nothing -> panic $ "no toplevel: " <> show i
  Lit x -> const (pure (Sca x))
  Inj i -> pure . Tag i
  Distr l -> \case
    Rec r -> case Map.lookup l r of
      Just y -> case y of
        Tag t z -> pure (Tag t (Rec (Map.insert l z r)))
        _ -> panic "bad1"
      Nothing -> panic "bad2"
    _ -> panic "bad 3"
  Proj l -> \case
    v@(Rec xs) -> case Map.lookup l xs of
      Just y -> pure y
      Nothing -> panic ("bad record projection, no key: " <> show l <> " " <> render v)
    _ -> panic ("bad record projection, not record: " <> show l)
  Comp fs -> foldr' comp pure fs
    where
      comp e cur = evalAr tops e >=> cur
  Tuple parts -> evalAr tops (Cone [(LcIdent ("_" <> show i), p) | (i, p) <- zip [1 :: Int ..] parts])
  Cone cone ->
    let ars = second (evalAr tops) <$> cone
     in \x -> do
          ys <- traverse (\(l, f) -> (l,) <$> f x) ars
          pure (Rec (Map.fromList ys))
  CoCone cocone ->
    let ars = Map.fromList $ second (evalAr tops) <$> cocone
     in \case
          Tag l x -> case Map.lookup l ars of
            Just f -> f x
            Nothing -> panic ("bad cocone: " <> show l <> " " <> render x)
          v -> panic ("bad cocone: " <> render v)

evalDecl :: Tops -> Decl -> (LcIdent, Val -> IO Val)
evalDecl tops = \case
  DAr name _ e -> (name, evalAr tops e)
  DMain e -> ("main", evalAr tops e)

lkp :: LcIdent -> Map LcIdent a -> Maybe a
lkp = Map.lookup

primTops :: Tops
primTops =
  Map.fromList
    [ "plus"
        =: \case
          Rec r
            | Just (Sca (Int x)) <- lkp "_1" r,
              Just (Sca (Int y)) <- lkp "_2" r ->
              pure (Sca (Int (x + y)))
          _ -> panic "bad plus",
      "print"
        =: \case
          v -> do
            putStrLn ("PRINT" :: Text)
            putStrLn (render v)
            pure (Rec mempty),
      "incr"
        =: \case
          Sca (Int x) -> pure (Sca (Int (x + 1)))
          _ -> panic "bad incr",
      "app"
        =: \case
          Rec r
            | Just (VFun ff) <- lkp "_1" r,
              Just aa <- lkp "_2" r ->
              ff aa
          v -> panic ("bad app: " <> render v)
    ]

(=:) :: a -> b -> (a, b)
(=:) = (,)

eval :: Val -> Decls -> IO Val
eval v ds =
  let tops = primTops <> Map.fromList [evalDecl tops d | d <- ds]
   in case Map.lookup "main" tops of
        Just m -> m v
        Nothing -> panic "No main!"

primsJS :: [(Text, Text)]
primsJS =
  [ "plus" =: "x => x._1 + x._2;",
    "print" =: "x => {console.log('PRINT', x);return {};}",
    "incr" =: "x => x+1;",
    "app" =: "x => x._1(x._2)"
  ]

jsCall1 :: Text -> Text -> Text
jsCall1 f x = f <> "(" <> x <> ")"

jsCall2 :: Text -> Text -> Text -> Text
jsCall2 f x y = f <> "(" <> x <> "," <> y <> ")"

jsCone :: [(LcIdent, Text)] -> Text
jsCone xs = "{" <> Text.intercalate "," [i <> ":" <> f | (LcIdent i, f) <- xs] <> "}"

evalJS :: Expr -> Text
evalJS = \case
  Lit x -> jsCall1 "mkConst" (render x)
  Tuple xs -> evalJS (Cone [(LcIdent ("_" <> show i), p) | (i, p) <- zip [1 :: Int ..] xs])
  EConst x -> jsCall1 "mkConst" (evalJS x)
  Proj (LcIdent i) -> jsCall1 "proj" (show i)
  Inj (LcIdent i) -> jsCall1 "inj" (show i)
  Top (LcIdent t) -> jsCall1 "top" (show t)
  Distr (LcIdent i) -> jsCall1 "distr" (show i)
  Comp xs -> foldl' go "identity" xs
    where
      go x e = jsCall2 "comp" x (evalJS e)
  Cone xs -> jsCall1 "cone" $ jsCone [(label, evalJS e) | (label, e) <- xs]
  CoCone xs -> jsCall1 "cocone" $ jsCone [(label, evalJS e) | (label, e) <- xs]

mkJS :: Decls -> Text
mkJS decls =
  jsPriv prelude "tops"
  where
    prelude =
      jsClone
        <> "var tops = {};\n"
        <> statements
          ["let " <> name <> " = " <> body | (name, body) <- jsCombis]
        <> statements (uncurry addTop <$> primsJS)
        <> statements (mkDecl <$> decls)
    mkDecl (DMain e) = "tops.main = " <> evalJS e
    mkDecl (DAr (LcIdent name) _ e) = addTop name (evalJS e)
    addTop name e = "tops[\"" <> name <> "\"] = " <> e
    statements xs = Text.intercalate "\n" ((<> ";") <$> xs)
    jsPriv :: Text -> Text -> Text
    jsPriv x r = "(function(){\n" <> x <> " return " <> r <> ";})()"
    jsCombis :: [(Text, Text)] =
      [ "identity" =: "x => x",
        "mkConst" =: "function(v){return function(_){ return v;};}",
        "comp" =: "function(f1, f2){ return function(x){ return f2(f1(x)); } }",
        "top" =: "i => { return function(x){ return tops[i](x); };}",
        "proj" =: "i => function(x){ return x[i];}",
        "inj" =: "i => function(x){ return {tag: i, val: x};}",
        "distr"
          =: "l =>\
             \ function(r){\
             \   let new_r = clone(r);\
             \   new_r[l] = r[l].val;\
             \   return {tag: r[l].tag, val: new_r};\
             \}",
        "cone"
          =: "c => function(x){return Object.fromEntries(Object.entries(c).map(([k,f]) => [k,f(x)]));}",
        "cocone" =: "(c) => function(x){return (c[x.tag])(x.val);}"
      ]

jsClone :: Text
jsClone = "function clone(e){if(null===e||\"object\"!=typeof e||\"isActiveClone\"in e)return e;if(e instanceof Date)var n=new e.constructor;else n=e.constructor();for(var t in e)Object.prototype.hasOwnProperty.call(e,t)&&(e.isActiveClone=null,n[t]=clone(e[t]),delete e.isActiveClone);return n}"