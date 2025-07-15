import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_login/auth/auth.dart';
import 'package:flutter_login/home/home.dart';
import 'package:flutter_login/login/login.dart';
import 'package:flutter_login/splash/splash.dart';
import 'package:auth_repo/auth_repo.dart';
import 'package:user_repo/user_repo.dart';


import 'package:api_service/api_service.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => ApiService()),
        RepositoryProvider(
          create: (context) => AuthenticationRepository(
            apiService: context.read<ApiService>(),
          ),
          dispose: (repository) => repository.dispose(),
        ),
        RepositoryProvider(create: (_) => UserRepository(apiService: context.read<ApiService>(),)),
      ],
      child: BlocProvider(
        lazy: false,
        create: (context) => AuthenticationBloc(
          authenticationRepository: context.read<AuthenticationRepository>(),
          userRepository: context.read<UserRepository>(),
        )..add(AuthenticationSubscriptionRequested()),
        child: const AppView(),
      ),
    );
  }
}

class AppView extends StatefulWidget {
  const AppView({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  NavigatorState get _navigator => _navigatorKey.currentState!;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      builder: (context, child) {
        return BlocListener<AuthenticationBloc, AuthenticationState>(
          listener: (context, state) {
            switch (state.status) {
              case AuthenticationStatus.authenticated:
                _navigator.pushAndRemoveUntil<void>(
                  HomePage.route(),
                  (route) => false,
                );
              case AuthenticationStatus.unauthenticated:
                _navigator.pushAndRemoveUntil<void>(
                  LoginPage.route(),
                  (route) => false,
                );
              case AuthenticationStatus.unknown:
                break;
            }
          },
          child: child,
        );
      },
      onGenerateRoute: (_) => SplashPage.route(),
    );
  }
}