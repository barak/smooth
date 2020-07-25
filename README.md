# smooth

Examples from the paper are located in the file `src/SmoothLang.hs`.
Each example is annotated with its approximate runtime.

For example, the paper (section 2) shows the computation of the the derivative of the `brightness` function which corresponds to the definition `runDerivBrightness` in `src/SmoothLang.hs`.

## Docker instructions

If necessary, set up the environment for Docker:
```
eval $(docker-machine env default)
```

The Dockerfile is at the base of the source code directory. To build a docker image from the Dockerfile, run from the base of the source directory the command
```
docker build --tag=smooth .
```

To run the Docker image, run (from the base directory)
```
docker load < docker-image.tar.gz    #load docker image (if saved)
docker run -it smooth             #run docker image
```

## Examples

The entire source directory is located at `/source/`.

To run examples from the paper, first navigate to `/src/` then you can view the examples file
with `vim SmoothLang.hs` and can run the examples with `stack ghci SmoothLang.hs`, which will
launch a repl with all of the examples loaded.

For example, the paper (section 1) shows the computation of the the derivative of the integral from 0 to 1 of the derivative of ReLU(x - c) at c=0.6.
This can be reproduced by running `runDerivIntegralRelu`. It should compute almost immediately and return
the interval [-0.4062500000000000000000, -0.3984375000000000000000].

Computations of type `Real` return a single interval which corresponds to the interval refined to
the precision specified with the `atPrec` function. On the other hand, computations of type
`DReal ()` produce and infinite stream of finer and finer results. This stream may be truncated
at any time with Ctrl+C.

Sample Session:
```
$ cd src
$ stack ghci SmoothLang.hs
```
Make sure things are working with some simple arithmetic:
```
*SmoothLang> atPrec 1e-9 $ sqrt 2
[1.4142135619, 1.4142135624]
```
Solution to the [Verhulst]( https://en.wikipedia.org/wiki/Pierre_Fran%C3%A7ois_Verhulst ) (1838) epidemic equation.
```
*SmoothLang> logistic x = 1 / (1 + exp (- x))
*SmoothLang> (\t -> atPrec 1e-9 $ deriv (ArrD (\_ t -> logistic t)) t - logistic t * (1 - logistic t)) (-5)
[-1.0913936421e-11, 1.0913936421e-11]
*SmoothLang> (\t -> atPrec 1e-9 $ deriv (ArrD (\_ t -> logistic t)) t - logistic t * (1 - logistic t)) (0)
[-0.00000000000, 0.00000000000]
*SmoothLang> (\t -> atPrec 1e-9 $ deriv (ArrD (\_ t -> logistic t)) t - logistic t * (1 - logistic t)) (2)
[-4.6566128731e-10, 5.2386894822e-10]
*SmoothLang> (\t -> atPrec 1e-9 $ deriv (ArrD (\_ t -> logistic t)) t - logistic t * (1 - logistic t)) (5)
[-5.1295501180e-10, 2.0190782379e-10]
```
If only we could solve modern epidemics so easily!

Rough edges in implementation, here’s a simple one:
```
*SmoothLang> map (\t -> atPrec 1e-9 $ deriv (ArrD (\_ t -> logistic t)) t - logistic t * (1 - logistic t)) [-5..5]

<interactive>:4:95: error:
    • No instance for (Enum (DReal ()))
        arising from the arithmetic sequence ‘- 5 .. 5’
    • In the second argument of ‘map’, namely ‘[- 5 .. 5]’
      In the expression:
        map
          (\ t
             -> atPrec 1e-9
                  $ deriv (ArrD (\ _ t -> logistic t)) t
                      - logistic t * (1 - logistic t))
          [- 5 .. 5]
      In an equation for ‘it’:
          it
            = map
                (\ t
                   -> atPrec 1e-9
                        $ deriv (ArrD (\ _ t -> logistic t)) t
                            - logistic t * (1 - logistic t))
                [- 5 .. 5]
```

Captured variables sometimes require special `dmap` treatment.
```
*SmoothLang> atPrec 1e-9 $ (\c -> deriv (ArrD (\_ t -> c*t^2)) 3) (1/2)
error:
    • Couldn't match type ‘Double’ with ‘R FwdPSh.D Real d’
      Expected type: DReal d
        Actual type: Double
    ...
*SmoothLang> atPrec 1e-9 $ (\c -> deriv (ArrD (\wk t -> dmap wk c*t^2)) 3) (1/2)
[3.0000000000, 3.0000000000]
*SmoothLang> let c = 1/2; in atPrec 1e-9 $ deriv (ArrD (\_ t -> c*t^2)) 3
[3.0000000000, 3.0000000000]
```

Now let’s try some [simple nesting]( http://barak.pearlmutter.net/papers/HOSC-forward-nesting.pdf ) of derivatives.
```
*SmoothLang> atPrec 1e-9 $ deriv (ArrD (\_ x -> x * deriv (ArrD (\wk y -> dmap wk x * y)) 2)) 1
[2.0000000000, 2.0000000000]
```
The `dmap wk x` is the moral equivalent of `auto x` in the Haskell ad package: it lifts an external value into the current differential domain.

Let’s try to define a higher-order function `d` that takes a derivative of its argument.
```
*Main SmoothLang> d f x = atPrec 1e-9 $ deriv (ArrD (\_ x -> f x)) x

<interactive>:241:44: error:
    • Couldn't match expected type ‘DReal d -> DReal d’
                  with actual type ‘p’
        because type variable ‘d’ would escape its scope
      This (rigid, skolem) type variable is bound by
        a type expected by the context:
          forall d. VectorSpace d => (d FwdMode.:~> ()) -> DReal d -> DReal d
        at <interactive>:241:30-47
    • In the expression: f x
      In the first argument of ‘ArrD’, namely ‘(\ _ x -> f x)’
      In the first argument of ‘deriv’, namely ‘(ArrD (\ _ x -> f x))’
    • Relevant bindings include
        x :: DReal d (bound at <interactive>:241:39)
        f :: p (bound at <interactive>:241:3)
        d :: p -> DReal () -> MPFR.Real (bound at <interactive>:241:1)
```
This is a limitation of Haskell’s type inference.

Now it is time to try the [*amazing bug*]( https://www.cambridge.org/core/journals/journal-of-functional-programming/article/perturbation-confusion-in-forward-automatic-differentiation-of-higherorder-functions/A808189A3875A2EDAC6E0D62CF2AD262 )...
```
*SmoothLang> s x f y = f # x + y
*SmoothLang> q = deriv (ArrD (\_ x -> s x)) 0
*SmoothLang> atPrec 1e-9 $ q (q (^2)) 1
```
Oops, none of that works.
