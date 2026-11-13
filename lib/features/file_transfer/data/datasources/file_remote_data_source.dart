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
        throw const TransferException(message: 'Selected file does not exist on device.');
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
          headers: {
            HttpHeaders.contentTypeHeader: 'multipart/form-data',
          },
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
      if (e is ServerException || e is NetworkException || e is TransferException) {
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
        ),
      );

      // Status 200 (OK for new file) or 206 (Partial Content for resumed file)
      if (response.statusCode == 200 || response.statusCode == 206) {
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
      if (e is ServerException || e is NetworkException || e is TransferException) {
        rethrow;
      }
      throw ServerException(message: e.toString());
    }
  }
}
