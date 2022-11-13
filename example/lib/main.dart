import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:refresh_token_manager/refresh_token_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences prefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Dio dio = Dio();
  int count = 0;
  int refreshCount = 0;
  String validToken = 'invalid'; // token on server
  String message = '';

  @override
  void initState() {
    super.initState();
    dio.interceptors.addAll([
      InterceptorsWrapper(onRequest: (
        RequestOptions options,
        RequestInterceptorHandler handler,
      ) {
        /// add Authorization header
        options.headers['Authorization'] = prefs.getString('token') ?? '';
        handler.next(options);
      }),
      InterceptorsWrapper(onRequest: (
        RequestOptions options,
        RequestInterceptorHandler handler,
      ) async {
        /// fake api call
        await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(1000)));
        count++;
        if (count == 5) {
          validToken = 'invalid';
        }
        if (validToken != '' && options.headers['Authorization'] == validToken) {
          handler.resolve(
              Response(
                requestOptions: options,
                data: {"status": "success"},
                statusCode: 200,
              ),
              true);
        } else {
          handler.reject(
              DioError(
                requestOptions: options,
                response: Response(requestOptions: options, data: {"status": "error"}, statusCode: 401),
              ),
              true);
        }
      }),
      /*
      InterceptorsWrapper(onError: (DioError e, ErrorInterceptorHandler handler) async {
        if (e.response?.statusCode == 401) {
          // execute refresh token
          refreshCount++;
          bool success = refreshCount > 5 && refreshCount < 50;
          await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(500)));
          String newValidToken = DateTime.now().toIso8601String();
          if (success) {
            validToken = newValidToken;
          }
          await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(500)));
          final ret = RefreshTokenResponse(
            status: success ? 200 : 500,
            refreshToken: success ? DateTime.now().toIso8601String() : null,
            token: success ? newValidToken : null,
            data: BasicTokenResponse(
              accessToken: success ? newValidToken : null,
              refreshToken: success ? DateTime.now().toIso8601String() : null,
              tokenType: "bearer",
              expiresIn: 10000,
            ),
          );
          if (ret.status == 200) {
            // save token
            await prefs?.setString('token', ret.token ?? '');
            await prefs?.setString('refreshToken', ret.refreshToken ?? '');
          }
          print("Refresh token: status ${ret.status} token: ${ret.token}");
        }
        handler.next(e);
      }),
      */
      RefreshTokenManagerInterceptor<BasicTokenResponse>(refreshMethod: () async {
        /// TODO: implement calling api to refresh token
        refreshCount++;
        bool success = refreshCount > 5 && refreshCount < 50;
        await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(500)));
        String newValidToken = DateTime.now().toIso8601String();
        if (success) {
          validToken = newValidToken;
        }
        await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(500)));
        //
        final ret = RefreshTokenResponse(
          status: success ? 200 : 500,
          refreshToken: success ? DateTime.now().toIso8601String() : null,
          token: success ? newValidToken : null,
          data: BasicTokenResponse(
            accessToken: success ? newValidToken : null,
            refreshToken: success ? DateTime.now().toIso8601String() : null,
            tokenType: "bearer",
            expiresIn: 10000,
          ),
        );
        if (ret.status == 200) {
          // save token
          await prefs.setString('token', ret.token ?? '');
          await prefs.setString('refreshToken', ret.refreshToken ?? '');
        }
        print("Refresh token: status ${ret.status} token: ${ret.token}");
        return ret;
      }, shouldRefreshToken: (err) {
        return err.response?.statusCode == 401;
      },),
      InterceptorsWrapper(onError: (DioError e, ErrorInterceptorHandler handler) async {
        /// Retry request
        final String currToken = prefs.getString('token') ?? '';
        if (e.response?.statusCode == 401 && e.requestOptions.headers['Authorization'] != currToken) {
          print('Retry ${e.requestOptions.path}');
          try {
            final res = await dio.fetch(e.requestOptions);
            handler.resolve(res);
            return;
          } catch (e) {
            // print('$e');
          }
        }
        handler.next(e);
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () async {
                refreshCount = 0;
                count = 0;
                validToken = prefs.getString('token') ?? 'valid';
                for (int i = 0; i < 100; i++) {
                  final index = i;
                  dio.get('request_$index').then((value) {
                    message = 'Response $index: status: ${value.statusCode} data: ${value.data}';
                    print(message);
                    setState(() {});
                  }).onError((error, stackTrace) {
                    message = 'Response $index: status: Dio error: $index ${(error as DioError).response?.statusCode}';
                    print(message);
                    setState(() {});
                  });
                }
              },
              child: const Text('Send refresh token request'),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                'message: $message',
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                'current Token: ${prefs.getString('token')}',
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                'current Refresh Token: ${prefs.getString('refreshToken')}',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
