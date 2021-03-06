module Main exposing (main)

import Html exposing (Html)
import Html.Attributes exposing (style, class)
import BallColor exposing (Color)
import Time exposing (Time)
import Keyboard
import Key
import String
import Random
import Array exposing (Array)
import Animation
import Audio
import Dict exposing (Dict)


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-- MODEL


type Model
    = Waiting
    | Playing PlayModel
    | Ended Score


type alias Score =
    Int


type alias PlayModel =
    { remaining : Time
    , color : Color
    , score : Score
    , style : Animation.State
    }


init : ( Model, Cmd Msg )
init =
    ( Waiting, Cmd.none )


start : ( Model, Cmd Msg )
start =
    ( Playing
        { remaining = totalTime
        , color = BallColor.default
        , score = 0
        , style =
            Animation.style
                [ Animation.opacity 0
                ]
        }
    , generateColor
    )


timeInterval : Time
timeInterval =
    Time.second


totalTime : Time
totalTime =
    3 * Time.minute



-- UPDATE


type Msg
    = Tick Time
    | KeyUp Keyboard.KeyCode
    | NewColor Color
    | Animate Animation.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        KeyUp keyCode ->
            keyUp keyCode model

        Tick time ->
            tick time model

        NewColor color ->
            changeColor color model

        Animate animation ->
            ( updateAnimation animation model, Cmd.none )


updateAnimation : Animation.Msg -> Model -> Model
updateAnimation animation model =
    case model of
        Playing submodel ->
            Playing
                { submodel
                    | style = Animation.update animation submodel.style
                }

        _ ->
            model


keyUp : Keyboard.KeyCode -> Model -> ( Model, Cmd Msg )
keyUp keyCode model =
    case Key.fromCode keyCode of
        Key.Space ->
            case model of
                Waiting ->
                    start

                Playing submodel ->
                    ( Playing
                        { submodel
                            | score = submodel.score + 1
                        }
                    , generateColor
                    )

                Ended _ ->
                    ( Waiting, Cmd.none )

        _ ->
            ( model, Cmd.none )


generateColor : Cmd Msg
generateColor =
    Random.generate NewColor BallColor.generator


changeColor : Color -> Model -> ( Model, Cmd Msg )
changeColor color model =
    case model of
        Playing submodel ->
            ( Playing
                { submodel
                    | color = color
                    , style =
                        Animation.interrupt
                            [ Animation.to
                                [ Animation.opacity 0
                                ]
                            , Animation.to
                                [ Animation.opacity 1
                                ]
                            ]
                            submodel.style
                }
            , Audio.play (BallColor.name color)
            )

        _ ->
            ( model, Cmd.none )


tick : Time -> Model -> ( Model, Cmd Msg )
tick time model =
    case model of
        Playing submodel ->
            if submodel.remaining > 0 then
                ( Playing
                    { submodel
                        | remaining = submodel.remaining - timeInterval
                    }
                , Cmd.none
                )
            else
                ( Ended submodel.score, Audio.play "gameOver" )

        Waiting ->
            ( model, Cmd.none )

        Ended _ ->
            ( model, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    Html.div
        [ class "container" ]
        [ viewCurrentScreen model ]


viewCurrentScreen : Model -> Html msg
viewCurrentScreen model =
    case model of
        Waiting ->
            viewStartScreen

        Playing submodel ->
            viewProgressScreen submodel

        Ended score ->
            viewFinalScore score


viewStartScreen : Html msg
viewStartScreen =
    Html.div
        [ class "welcome-screen" ]
        [ Html.text "Press the button to start" ]


viewProgressScreen : PlayModel -> Html msg
viewProgressScreen model =
    Html.div
        [ class "progress-screen" ]
        [ viewTime model.remaining
        , viewColor model.color model.style
        , viewScore model.score
        ]


viewTime : Time -> Html msg
viewTime time =
    Html.div
        [ class "timer"
        ]
        [ minutesAndSeconds time
            |> Html.text
        ]


minutesAndSeconds : Time -> String
minutesAndSeconds time =
    let
        raw =
            round (Time.inSeconds time)

        minutes =
            raw // 60 |> toString

        seconds =
            rem raw 60 |> toString
    in
        [ minutes, seconds ]
            |> List.map (String.padLeft 2 '0')
            |> String.join ":"


viewColor : Color -> Animation.State -> Html msg
viewColor color currentStyle =
    Html.div
        (Animation.render currentStyle
            ++ [ class "current-color"
               , style
                    [ ( "background-color", BallColor.cssColor color )
                    ]
               ]
        )
        []


viewScore : Score -> Html msg
viewScore score =
    Html.div
        [ class "score" ]
        [ Html.text ("Score: " ++ toString score) ]


viewFinalScore : Score -> Html msg
viewFinalScore score =
    Html.div
        [ class "score-screen" ]
        [ Html.div
            []
            [ Html.text "Final score" ]
        , Html.div
            [ class "final-score" ]
            [ Html.text (toString score) ]
        , Html.div
            [ class "restart-hint" ]
            [ Html.text "Press the button to play again" ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        -- TODO: throttle ?
        [ Keyboard.ups KeyUp
        , Time.every timeInterval Tick
        , animationSubscription model
        ]


animationSubscription : Model -> Sub Msg
animationSubscription model =
    case model of
        Playing submodel ->
            Animation.subscription Animate [ submodel.style ]

        _ ->
            Sub.none
