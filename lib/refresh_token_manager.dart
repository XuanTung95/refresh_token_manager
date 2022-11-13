library refresh_token_manager;

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:synchronized/synchronized.dart' as sync;

typedef RefreshTokenMethod<T> = Future<RefreshTokenResponse<T>> Function();

class RefreshTokenManager<T> {
  final Map<String, RefreshTokenResponse<T>> _result = {};
  final lock = sync.Lock();

  /// Execute refresh token synchronized
  Future<RefreshTokenResponse<T>> refreshToken({
    required String currentToken,
    required RefreshTokenMethod<T> method,
  }) async {
    final ret = await lock.synchronized<RefreshTokenResponse<T>>(() async {
      try {
        final RefreshTokenResponse<T>? prevResult = _result[currentToken];
        if (prevResult != null && prevResult.status == 200) {
          return prevResult;
        }
        final RefreshTokenResponse<T> res = await method.call();
        _result[currentToken] = res;
        return res;
      } catch (e) {
        return RefreshTokenResponse(status: 500, error: e);
      }
    });
    return ret;
  }
}

class RefreshTokenManagerInterceptor<T> extends Interceptor {
  final bool Function(DioError err)? shouldRefreshToken;
  final RefreshTokenMethod<T> refreshMethod;
  final RefreshTokenManager refreshManager = RefreshTokenManager();

  RefreshTokenManagerInterceptor({
    required this.refreshMethod,
    this.shouldRefreshToken,
  });

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) async {
    bool refresh = false;
    if (shouldRefreshToken != null) {
      refresh = shouldRefreshToken!.call(err);
    } else {
      refresh = err.response?.statusCode == 401;
    }
    if (refresh) {
      await refreshManager.refreshToken(currentToken: err.requestOptions.headers['Authorization'] ?? '', method: refreshMethod);
    }
    handler.next(err);
  }
}

class RefreshTokenResponse<T> {
  final T? data;
  final int status;
  final String? token;
  final String? refreshToken;
  final dynamic error;

  const RefreshTokenResponse({
    this.data,
    required this.status,
    this.token,
    this.refreshToken,
    this.error,
  });
}

class BasicTokenResponse {
  String? accessToken;
  String? tokenType;
  int? expiresIn;
  String? refreshToken;
  String? scope;

  BasicTokenResponse({this.accessToken, this.tokenType, this.expiresIn, this.refreshToken, this.scope});

  BasicTokenResponse.fromJson(Map<String, dynamic> json) {
    accessToken = json['access_token'];
    tokenType = json['token_type'];
    expiresIn = json['expires_in'];
    refreshToken = json['refresh_token'];
    scope = json['scope'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['access_token'] = accessToken;
    data['token_type'] = tokenType;
    data['expires_in'] = expiresIn;
    data['refresh_token'] = refreshToken;
    data['scope'] = scope;
    return data;
  }
}
