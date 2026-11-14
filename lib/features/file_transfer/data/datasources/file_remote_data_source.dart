import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/file_item_model.dart';

abstract class FileRemoteDataSource {
  Future<List<FileItemModel>> listFiles();

  Future<void> deleteFile(String fileName);

  Future<Response> uploadFile({
    required String filePath,
    required String fileName,
    required ProgressCallback onSendProgress,
    required CancelToken cancelToken,
  });

  Future<Response<ResponseBody>> downloadFileStream({
    required String fileName,
    int startByte = 0,
    required CancelToken cancelToken,
  });
}

class FileRemoteDataSourceImpl implements FileRemoteDataSource {
  final DioClient dioClient;

  FileRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<FileItemModel>> listFiles() async {
    try {
      final response = await dioClient.dio.get(
        ApiConstants.listFilesEndpoint,
      );

      if (response.statusCode == 200) {
        return FileItemModel.fromResponse(response.data);
      } else {
        throw ServerException(
          message: 'Failed to list files with status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw dioClient.handleDioException(e);
    } catch (e) {
      if (e is ServerException || e is NetworkException || e is AuthException) {
        rethrow;
      }
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteFile(String fileName) async {
    try {
      final response = await dioClient.dio.delete(
        ApiConstants.deleteEndpoint,
        queryParameters: {'file': fileName},
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException(
          message: 'Failed to delete file with status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw dioClient.handleDioException(e);
    } catch (e) {
      if (e is ServerException || e is NetworkException || e is AuthException) {
        rethrow;
      }
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Response> uploadFile({
    required String filePath,
    required String fileName,
    required ProgressCallback onSendProgress,
    required CancelToken cancelToken,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw const TransferException(
          message: 'File not found, please pick it again.',
        );
      }
      if (await file.length() <= 0) {
        throw const TransferException(message: 'This file is empty.');
      }

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
        ),
      });

      final response = await dioClient.dio.post(
        ApiConstants.uploadEndpoint,
        data: formData,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
        options: Options(
          // Keep connectTimeout from DioClient BaseOptions.
          // Do not use the short global sendTimeout — it applies to the entire
          // multipart body and aborts large/slow uploads. Dio sets the multipart
          // Content-Type (with boundary) itself; do not set it manually.
          sendTimeout: ApiConstants.uploadSendTimeout,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response;
      } else {
        throw ServerException(
          message: 'Upload failed with status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw dioClient.handleDioException(e);
    } catch (e) {
      if (e is ServerException ||
          e is NetworkException ||
          e is TransferException ||
          e is AuthException) {
        rethrow;
      }
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Response<ResponseBody>> downloadFileStream({
    required String fileName,
    int startByte = 0,
    required CancelToken cancelToken,
  }) async {
    try {
      final headers = <String, dynamic>{};
      if (startByte > 0) {
        headers[HttpHeaders.rangeHeader] = 'bytes=$startByte-';
      }

      final response = await dioClient.dio.get<ResponseBody>(
        ApiConstants.downloadEndpoint,
        queryParameters: {'file': fileName},
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          // 416 = Range Not Satisfiable (e.g. .part already complete).
          validateStatus: (status) =>
              status != null &&
              (status == 200 || status == 206 || status == 416),
        ),
      );

      // 200 (full), 206 (partial resume), 416 (range unsatisfiable — caller decides)
      if (response.statusCode == 200 ||
          response.statusCode == 206 ||
          response.statusCode == 416) {
        return response;
      } else {
        throw ServerException(
          message: 'Download failed with status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw dioClient.handleDioException(e);
    } catch (e) {
      if (e is ServerException ||
          e is NetworkException ||
          e is TransferException ||
          e is AuthException) {
        rethrow;
      }
      throw ServerException(message: e.toString());
    }
  }
}
