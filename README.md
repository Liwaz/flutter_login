# flutter_login

A flutter project to understand simple login flow using blocs - bloclibrary.dev

# Getting Started

This project is a starting point for a Flutter application with simple login.

# Auth Repo (Authentication Repository).
We will start by creating an auth repo package which will be responsible for managing the authentication domain.

## packages/auth_repo/pubspec.yaml
name: authentication_repository
description: Dart package which manages the authentication domain.
publish_to: none

environment:
  sdk: ">=3.8.0 <4.0.0"

## packages/auth_repo/lib/src/auth_repo.dart
The AuthenticationRepository exposes a stream of AuthenticatonStatus updates which will be used to notify the application when a user signs in or out.

packages/authentication_repository/lib/authentication_repository.dart
This will contain the public exports.

# User Repo (User Repository).
We will create a user_repo package inside the packages directory

## packages/user_repo/pubspec.yaml
name: user_repository
description: Dart package which manages the user domain.
publish_to: none

environment:
  sdk: ">=3.8.0 <4.0.0"

dependencies:
  equatable: ^2.0.0
  uuid: ^3.0.0

## packages/user_repo/lib/src/models/user.dart
Define the user model

## packages/user_repo/lib/src/models
Which will export all models ao that we can use a single import state to import multiple models

## packages/user_repo/lib/src/user_repo.dart
Implement the UserRepository class.

## Installing Dependencies
Add the following to the pubpec.yaml at root of the project.
dependencies:
  authentication_repository:
    path: packages/auth_repo
  bloc: ^9.0.0
  equatable: ^2.0.0
  flutter:
    sdk: flutter
  flutter_bloc: ^9.1.0
  formz: ^0.8.0
  user_repository:
    path: packages/user_repo

Install dependencies by running or just saving the vscode will run pub get automatically:
flutter pub get 

# Auth Bloc (Authentication Bloc).
This will be responsible for reacting to changes in the authentication state (exposed by the AuthRepo) and will emit states we can react to in the presentation layer.

The implementation for the Auth Bloc is inside of lib/auth because we treat auathenticatin=on as a feature in our application layer.

## auth_event.dart
**AuthenticationEvent** instances will be the input to the *AuthenticationBloc* and will be processed and used to emit new Authentication instances.

**AuthenticationBloc** will be reacting to two different events:
    AuthenticationSubscriptionRequested: Initial event that notofies the bloc to subscribe to the AuthenticationEvent stream.
    AuthenticationLogoutPtessed: notifies the bloc of a user logout action.

The authenticationBloc has a dependanacy on both the AuthenticationRepository and UserRepository and defines the initial state as Authenticationstate.unknown().

In the constructor of AuthenticationEvent subclasses are mapped to their corresponding evnt handlers.

In the **_onSubscriptionRequested** event handler, the Authentication uses emit.onEach to subscribe to the status stream of the AuthenticationRepository and emit a state in response to each AuthenticationStatus.

**Emit.onEach** creates a stream subscription internally and takes care of cancelling it when either *AuthenticationBloc* or the *status* stream is closed.

If the *status* stream emits an error, *addError* forwards the error and stackTrace to any *BlocObserver* listening.

When the **status** stream emits *AuthenticationStatus.unknown* or *unauthenticated*, the corresponding *AutheticationState* is emitted. 

When AuthenticationStatus.authenticated is emitted, the *AuthenticationBloc* queries the user via the *UserRepsoitory*

# main.dart

Replace defualt main.dart with:

`
import 'package:flutter/widgets.dart';
import 'package:flutter_login/app.dart';

void main() => runApp(const App());
`
# App
*aap.dart* will contain the root App widget for the entire application.

>***Note***: app.dart is split into two parts *App* and *AppView*. *App* is responsible for creating/providing the *AuthenticationBloc* which will be consumed by the *AppView*. This decoupling will enable us to easilly test both the *App* and *AppView* widgets later on.

>***Note*** *RepositoryProvider* is used to provide a single instance of *AuthenticationRepository* to the *entire* application which will come in handy later. 

By default *BlocProvider* is lazy and does not call create. By setting **lazy:false** we explicitly opt out of this behaviour, since *AuthenticationBloc* should always subscribe to the *AuthenticationStatus* stream *immediately* (via the *AuthenticationSubscriptionRequested* event).

*AppView* is a *StatefulWidget* because it maintains a *GlobalKey* which is used to access the *NavigatorState*.

# Splash
The splash feature will just contain a simple view which will be rendered right when the app is lauched while the app determines whether the user is authenticated.

Splash page exposes a static *Route* which makes it very easy to navigate to via *Navigator.of(context).push(SplashPage.Route())*.

# Login
This feature contains a LoginPage, LoginForm and LoginBloc and allows users to enter a username and password to logiin to the application.

We are using *package:formz* to create reuseable and standard models for the username and password.

# Login Bloc
The **LoginBloc** manages the state of the *LoginForm* and takes care validating the username and password input as well as the state of the form

### login_event.dart
Three different login types:
    - LoginUsernameChanged: Notifies the bloc that the username has been modified.
    - LoginPasswordChanged: Notifies the Bloc that the password has been modified.
    - LoginSubmitted: notifies the bloc that the form has been submitted.

### Login_bloc.dart
**Loginbloc** is responsible for reacting to user interactions in the *LoginForm* and handling the validation and submission of the form.

The login block has a dependancy on the AuthenticationRepository because when the form is submitted, it invokes login. The initial state of the bloc is pure meaning neither the inputs nor the form has been touched or interacated with (a virgin?).

Whenever either the username or password change, the bloc will create a sirty variant of the **Username/Password** model and updates the status based on the outcomeof the request.

When the login submitted event is added, if the current status of the form is valid, the boc makes a call to login and updates the status based on the outcome of the request.

### Login Page (view/login_page.dart)
The **LoginPage** is reponsible for exposing the Route as well as creating and providing the **LoginBloc** to the **LoginForm**.

### Login Form (view/login_form.dart)
**LoginForm** handles notifying the *LoginBloc* of user events and also responds to state changes using *BlocBuilder* and *BlocListner*.

**BlockListner** is used to show a *SnackBar* if the login submission fails. In addition, *context.select* is used to efficiently access specific parts of the *LoginState* for each widget, preventing unnecessary rebuilds. The onChanged callback is used to notify the LoginBloc of changes to the username/password.




