
module Exercise2b where

--------------------------------------------------------------------------------
-- Instructions
{-
Complete the holes in the proof below

The trick is to choose the right argument on which to do induction.
You may want to consult Pierce's book (Chapter 12) or the Coquand note
on the website.
-}
--------------------------------------------------------------------------------

------------------------------------------------------------------------
-- Prelude.
--------------------------------------------------------------------------------

-- Equality, and laws.
data _==_ {a : Set} (x : a) : a -> Set where
 Refl : x == x

cong : forall {a b x y} -> (f : a -> b) -> x == y -> f x == f y
cong f Refl = Refl

symmetry : {a : Set} -> {x y : a} -> x == y -> y == x
symmetry Refl = Refl

transitivity : {a : Set} -> {x y z : a} -> x == y -> y == z -> x == z
transitivity Refl Refl = Refl

-- Lists.
data List (a : Set) : Set where
 []   : List a
 _::_ : a -> List a -> List a

-- Pairs.
data Pair (a b : Set) : Set where
  _,_ : a -> b -> Pair a b

fst : forall {a b} -> Pair a b -> a
fst (x , _) = x

snd : forall {a b} -> Pair a b -> b
snd (_ , x) = x

-- Unit type.
data Unit : Set where
 U : Unit

-- The empty type and negation.
data Absurd : Set where

Not : Set -> Set
Not x = x -> Absurd

contradiction : {a : Set} -> Absurd -> a
contradiction ()

------------------------------------------------------------------------
-- Types and terms.
--------------------------------------------------------------------------------

-- Unit and function types are supported.
data Type : Set where
 O    : Type
 _=>_ : Type -> Type -> Type

el : Type -> Set
el O = Unit
el (s => t) = el s -> el t

-- Type context: the top of this list is the type of the innermost
-- abstraction variable, the next element is the type of the next
-- variable, and so on.
Context : Set
Context = List Type

-- Reference to a variable, bound during some abstraction.
data Ref : Context -> Type -> Set where
 Top : forall {G u} -> Ref (u :: G) u
 Pop : forall {G u v} -> Ref G u -> Ref (v :: G) u

-- A term in the lambda calculus. The language solely consists of
-- abstractions, applications and variable references.
mutual
  data Term : Context -> Type -> Set where
   Abs : forall {G u v} -> (body : Term (u :: G) v) -> Term G (u => v)
   App : forall {G u v} -> (f : Term G (u => v)) -> (x : Term G u) -> Term G v
   Var : forall {G u} -> Ref G u -> Term G u


  data Env : List Type -> Set where
    Nil  : Env []
    Cons : forall {ctx ty} -> Closed ty -> Env ctx -> Env (ty :: ctx)

  data Closed : Type -> Set where
    Closure : forall {ctx ty} -> (t : Term ctx ty) -> (env : Env ctx) -> Closed ty
    Clapp : forall {ty ty'} -> (f : Closed (ty => ty')) (x : Closed ty) ->
               Closed ty'


IsValue : forall {ty} -> Closed ty -> Set
IsValue (Closure (Abs t) env) = Unit
IsValue (Closure (App t t₁) env) = Absurd
IsValue (Closure (Var x) env) = Absurd
IsValue (Clapp t t₁) = Absurd

------------------------------------------------------------------------
-- Step-by-step evaluation of terms.

lookup : forall {ctx ty} -> Ref ctx ty -> Env ctx -> Closed ty
lookup Top (Cons x env) = x
lookup (Pop i) (Cons x env) = lookup i env



data Step : forall {ty} -> Closed ty -> Closed ty -> Set where
  AppL : {ty ty' : Type} (f f' : Closed (ty => ty')) (x : Closed ty) ->
    Step f f' -> Step (Clapp f x) (Clapp f' x)
  Beta : {ty ty' : Type} {ctx : Context} (body : Term (ty :: ctx) ty') (v : Closed ty)
    {env : Env ctx} ->
    Step (Clapp (Closure (Abs body) env) v) (Closure body (Cons v env))
  Lookup : {ctx : List Type} {ty : Type} {i : Ref ctx ty} {env : Env ctx} ->
          Step (Closure (Var i) env) (lookup i env)
  Dist : {ty ty' : Type} {ctx : List Type} {env : Env ctx} {f : Term ctx (ty => ty')} {x : Term ctx ty} ->
         Step (Closure (App f x) env) (Clapp (Closure f env) (Closure x env))


-- Reducibility.
data Reducible : forall {ty} -> Closed ty -> Set where
 Red : forall {ty} -> {c1 c2 : Closed ty} -> Step c1 c2 -> Reducible c1

-- Non-reducable terms are considered normal forms.
NF : forall {ty} -> Closed ty -> Set
NF c = Not (Reducible c)

-- A sequence of steps that can be applied in succession.
data Steps : forall {ty} -> Closed ty -> Closed ty -> Set where
 Nil  : forall {ty} -> {c : Closed ty} -> Steps c c
 Cons : forall {ty} -> {c1 c2 c3 : Closed ty} -> Step c1 c2 -> Steps c2 c3 -> Steps c1 c3

--------------------------------------------------------------------------------
-- Termination
--------------------------------------------------------------------------------

-- Definition of termination: a sequence of steps exist that ends up in a normal form.
data Terminates : forall {ty} -> Closed ty -> Set where
  Halts : forall {ty} -> {c nf : Closed ty} -> NF nf -> Steps c nf -> Terminates c

Normalizable : (ty : Type) -> Closed ty -> Set
Normalizable O c = Terminates c
Normalizable (ty => ty₁) f =
  Pair (Terminates f)
       ((x : Closed ty) -> Normalizable ty x -> Normalizable ty₁ (Clapp f x))

-- Structure that maintains normalization proofs for all elements in the environment.
NormalizableEnv : forall {ctx} -> Env ctx -> Set
NormalizableEnv Nil = Unit
NormalizableEnv (Cons {ctx} {ty} x env) = Pair (Normalizable ty x) (NormalizableEnv env)

-- Normalization implies termination.
normalizable-terminates : forall {ty c} -> Normalizable ty c -> Terminates c
normalizable-terminates {O} (Halts x x₁) = Halts x x₁
normalizable-terminates {ty => ty₁} (x , x₁) = x

-- Helper lemma's for normalization proof.
normalizableStep : forall {ty} -> {c1 c2 : Closed ty} -> Step c1 c2 ->
                   Normalizable ty c2 -> Normalizable ty c1
normalizableStep {O} step (Halts x x₁) = Halts x (Cons step x₁)
normalizableStep {ty => ty₁} step (x , x₁) = {!!}

normalizableSteps : forall {ty} -> {c1 c2 : Closed ty} -> Steps c1 c2 ->
                    Normalizable ty c2 -> Normalizable ty c1
normalizableSteps Nil n = n
normalizableSteps (Cons x steps) n = normalizableStep x (normalizableSteps steps n)

-- The following three lemmas may use mutual recursion. This is done
-- in Agda by separating the type signature and the function
-- definition.

mutual
-- Closed applications of the form 'f x' are normalizable when both f and x are normalizable.
  clapp-normalization : forall {A B} -> {c1 : Closed (A => B)} -> {c2 : Closed A} ->
                       Normalizable (A => B) c1  -> Normalizable A c2 -> Normalizable B (Clapp c1 c2)
  clapp-normalization {c1 = c1} {c2 = c2} (x , x₁) nC2 = closure-normalization (Cons (Clapp c1 c2) Nil) (x₁ c2 nC2 , U) (normalizable-env (Cons (Clapp c1 c2) Nil))

-- All closure terms are normalizable.
  closure-normalization : forall {ctx} -> {ty : Type} -> {t : Term ctx ty} -> {env : Env ctx} ->
                          NormalizableEnv env -> Normalizable ty (Closure t env)
  closure-normalization {ty = O} {App term1 term2} {env} nEnv with closure-normalization {t = term1} nEnv
                                                                 | closure-normalization {t = term2} nEnv
  ... | t1N | t2N = {!!}
  closure-normalization {ty = O} {t = Var x} {env} nEnv = {!   !}
  closure-normalization {ty = ty => ty₁} {t = term} {env} nEnv = {!   !}

  -- An environment is always normalizable
  normalizable-env : forall {ctx : Context} {env : Env ctx} -> NormalizableEnv env
  normalizable-env {env = Nil} = U
  normalizable-env {env = Cons (Closure t env') env} = closure-normalization normalizable-env , normalizable-env
  normalizable-env {env = Cons (Clapp x x2) env} = normalizable-env , normalizable-env


-- All terms are normalizable.
normalization : {ty : Type} -> (c : Closed ty) -> Normalizable ty c
normalization {t} (Closure t' env) with normalizable-env {env = env}
... | nEnv = closure-normalization {ty = t} {t = t'} nEnv
normalization {t} (Clapp c1 c2) with normalization c1 | normalization c2
... | nC1 | nC2 = clapp-normalization nC1 nC2

termination : {ty : Type} -> (c : Closed ty) -> Terminates c
termination c with normalization c
... | n = normalizable-terminates n
