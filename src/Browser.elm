module Browser exposing
  ( staticPage
  , sandbox
  , embed
  , fullscreen
  , View
  , Env
  , Url
  , focus, blur, DomError(..)
  , scrollIntoView
  , getScroll
  , setScrollTop, setScrollBottom
  , setScrollLeft, setScrollRight
  )

{-| This module helps you set up an Elm `Program` with functions like
[`sandbox`](#sandbox) and [`fullscreen`](#fullscreen).

It also has a bunch of miscellaneous helpers for focusing and scrolling DOM
nodes.


# Static Pages
@docs staticPage

# Dynamic Pages
@docs sandbox, embed, fullscreen, View, Env, Url

# DOM Stuff

## Focus
@docs focus, blur, DomError

## Scroll
@docs scrollIntoView, getScroll, setScrollTop, setScrollBottom, setScrollLeft, setScrollRight

-}



import Dict
import Browser.Navigation.Manager as Navigation
import Elm.Kernel.Browser
import Json.Decode as Decode
import Process
import Task exposing (Task)
import VirtualDom



-- PROGRAMS


{-| Show some static HTML.

    import Browser exposing (staticPage)
    import Html exposing (text)

    main =
      staticPage (text "Hello!")

Using `staticPage` means that all user input is ignored. For example, the
events generated by button presses are sent to a black hole of nothingness,
never to be heard from again. Try out [`sandbox`](#sandbox) to make an
interactive Elm program!
-}
staticPage : VirtualDom.Node msg -> Program () () msg
staticPage =
  Elm.Kernel.Browser.staticPage


{-| Create a “sandboxed” program that cannot communicate with the outside
world.

This is great for learning the basics of [The Elm Architecture][tea]. You can
see sandboxes in action in tho following examples:

  - [Buttons](http://elm-lang.org/examples/buttons)
  - [Text Field](http://elm-lang.org/examples/field)
  - [Checkboxes](http://elm-lang.org/examples/checkboxes)

Those are nice, but **I very highly recommend reading [this guide][guide]
straight through** to really learn how Elm works. Understanding the
fundamentals actually pays off in this language!

[tea]: https://guide.elm-lang.org/architecture/
[guide]: https://guide.elm-lang.org/
-}
sandbox :
  { init : model
  , view : model -> VirtualDom.Node msg
  , update : msg -> model -> model
  }
  -> Program () model msg
sandbox { init, view, update } =
  embed
    { init = \_ -> ( init, Cmd.none )
    , view = view
    , update = \msg model -> ( update msg model, Cmd.none )
    , subscriptions = \_ -> Sub.none
    }


{-| Create a program that can be embedded in a larger JavaScript project.
This is a great low-risk way of introducing Elm into your existing work, and
lots of companies that use Elm started with this approach!

Unlike a [`sandbox`](#sandbox), an “embedded” program can talk to the outside
world in a couple ways:

  - `Cmd` &mdash; you can “command” the Elm runtime to do stuff, like HTTP.
  - `Sub` &mdash` you can “subscribe” to event sources, like clock ticks.
  - `flags` &mdash; JavaScript can pass in data when starting the Elm program
  - `ports` &mdash; set up a client-server relationship with JavaScript

As you read [the guide][guide] you will run into a bunch of examples of `embed`
in [this section][fx]. You can learn more about flags and ports in [the interop
section][interop].

[guide]: https://guide.elm-lang.org/
[fx]: https://guide.elm-lang.org/architecture/effects/
[interop]: https://guide.elm-lang.org/interop/
-}
embed :
  { init : flags -> (model, Cmd msg)
  , view : model -> VirtualDom.Node msg
  , update : msg -> model -> ( model, Cmd msg )
  , subscriptions : model -> Sub msg
  }
  -> Program flags model msg
embed =
  Elm.Kernel.Browser.embed


{-| Create a fullscreen Elm program. This expands the functionality of
[`embed`](#embed) in two important ways:

  1. The `view` gives you control over the `<title>` and `<body>`.

  2. The `onNavigation` field lets you capture URL changes. This
  allows you to create single-page apps (SPAs) with the help of the
  [`Browser.Navigation`](Browser-Navigation) module.

You also get an [`Env`](#Env) value on `init` which gives a bit more
information about the host browser.

Here are some example usages of `fullscreen` programs:

  - [RealWorld example app](https://github.com/rtfeldman/elm-spa-example)
  - [Elm’s package website](https://github.com/elm-lang/package.elm-lang.org)

These are quite advanced Elm programs, so be sure to go through [the
guide](https://guide.elm-lang.org/) first to get a solid conceptual foundation
before diving in! If you start reading a calculus book from page 314, it might
seem confusing. Same here!
-}
fullscreen :
  { init : Env flags -> (model, Cmd msg)
  , view : model -> View msg
  , update : msg -> model -> ( model, Cmd msg )
  , onNavigation : Maybe (Url -> msg)
  , subscriptions : model -> Sub msg
  }
  -> Program flags model msg
fullscreen impl =
  Elm.Kernel.Browser.fullscreen <|
    case impl.onNavigation of
      Nothing ->
        impl

      Just toMsg ->
        { impl | subscriptions = Navigation.addListen toMsg impl.subscriptions }


{-| This data specifies the `<title>` and all of the nodes that should go in
the `<body>`. This means you can update the title as people navigate through
your single-page app.
-}
type alias View msg =
  { title : String
  , body : List (VirtualDom.Node msg)
  }



-- ENVIRONMENT


{-| When you initialize an Elm program, you get some information about the
environment. Right now this contains:

  - `url` &mdash; The initial [`Url`](#Url) of the page. If you are creating
  a single-page app (SPA) you need this information to figure out what to show
  on screen! If you are not making an SPA, you can ignore this.

  - `flags` &mdash; This holds data that is passed in from JavaScript.
-}
type alias Env flags =
  { url : Url
  , flags : flags
  }



-- URL


{-| A bunch of information about the URL in the address bar. You should always
be using the [`elm-lang/url`][url] package to turn these URLs into nice Elm
data. Check out the [`Url.Parser`][parser] module in particular.

[url]: http://package.elm-lang.org/packages/elm-lang/url/latest
[parser]: http://package.elm-lang.org/packages/elm-lang/url/latest/Url-Parser

**Note:** The fields correspond with the fields in `document.location` as
described [here](https://developer.mozilla.org/en-US/docs/Web/API/Url).
-}
type alias Url =
  { href : String
  , host : String
  , hostname : String
  , protocol : String
  , origin : String
  , port_ : String
  , pathname : String
  , search : String
  , hash : String
  , username : String
  , password : String
  }



-- DOM STUFF


{-| All the DOM functions here look nodes up by their `id`. If you ask for an
`id` that is not in the DOM, you will get this error.
-}
type DomError = NotFound String



-- FOCUS


{-| Find a DOM node by `id` and focus on it. So if you wanted to focus a node
like `<input type="text" id="search-box">` you could say:

    import Browser
    import Task

    type Msg = NoOp

    focusSearchBox : Cmd Msg
    focusSearchBox =
      Task.attempt (\_ -> NoOp) (Browser.focus "search-box")

Notice that this code ignores the possibility that `search-box` is not used
as an `id` by any node, failing silently in that case. It would be better to
log the failure with whatever error reporting software you use.
-}
focus : String -> Task DomError ()
focus =
  Elm.Kernel.Browser.call "focus"


{-| Find a DOM node by `id` and make it lose focus. So if you wanted a node
like `<input type="text" id="search-box">` to lose focus you could say:

    import Browser
    import Task

    type Msg = NoOp

    unfocusSearchBox : Cmd Msg
    unfocusSearchBox =
      Task.attempt (\_ -> NoOp) (Browser.blur "search-box")
-}
blur : String -> Task DomError ()
blur =
  Elm.Kernel.Browser.call "blur"




-- SCROLL


{-| Find a DOM node by `id` and scroll it into view. Maybe we want to scroll
to arbitrary headers in a long document? We could define a `scrollTo`
function like this:

    import Browser
    import Task

    type Msg = NoOp

    scrollTo : String -> Cmd Msg
    scrollTo id =
      Task.attempt (\_ -> NoOp) (Browser.scrollIntoView id)
-}
scrollIntoView : String -> Task DomError ()
scrollIntoView =
  Elm.Kernel.Browser.call "scrollIntoView"


{-| Find a DOM node by `id` and get its `scrollLeft` and `scrollTop` values.
-}
getScroll : String -> Task DomError ( Float, Float )
getScroll =
  Elm.Kernel.Browser.getScroll


{-| Find a DOM node by `id` and set the scroll offset from the top. If we want
to scroll to the top, we can say:

    import Browser
    import Task

    type Msg = NoOp

    scrollToTop : String -> Cmd Msg
    scrollToTop id =
      Task.attempt (\_ -> NoOp) (Browser.setScrollTop id 0)

So the offset from the top is zero. If we said `setScrollTop id 100` the
content would be scrolled down 100 pixels.
-}
setScrollTop : String -> Float -> Task DomError ()
setScrollTop =
  Elm.Kernel.Browser.setPositiveScroll "scrollTop"


{-| Same as [`setScrollTop`](#setScrollTop), but it sets the scroll offset
from the bottom. So saying `setScrollBottom id 0` scrolls all the way down.
That can be useful in a chat room where messages keep appearing.

If you said `setScrollBottom id 200`, it is like you scrolled all the way to
the bottom and then scrolled up 200 pixels.
-}
setScrollBottom : String -> Float -> Task DomError ()
setScrollBottom =
  Elm.Kernel.Browser.setNegativeScroll "scrollTop" "scrollHeight"


{-| Same as [`setScrollTop`](#setScrollTop), but it sets the horizontal scroll
offset from the left side.
-}
setScrollLeft : String -> Float -> Task DomError ()
setScrollLeft =
  Elm.Kernel.Browser.setPositiveScroll "scrollLeft"


{-| Same as [`setScrollTop`](#setScrollTop), but it sets the horizontal scroll
offset from the right side.
-}
setScrollRight : String -> Float -> Task DomError ()
setScrollRight =
  Elm.Kernel.Browser.setNegativeScroll "scrollLeft" "scrollWidth"

