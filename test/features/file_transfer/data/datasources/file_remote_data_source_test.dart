import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:laantech_task/core/constants/api_constants.dart';
import 'package:laantech_task/core/errors/exceptions.dart';
import 'package:laantech_task/core/network/dio_client.dart';
import 'package:laantech_task/features/file_transfer/data/datasources/file_remote_data_source.dart';

class MockDioClient extends Mock implements DioClient {}
class MockDio extends Mock implements Dio {}

void main() {
  late MockDioClient mockDioClient;
  late MockDio mockDio;
  late FileRemoteDataSourceImpl dataSource;

  setUp(() {
    mockDioClient = MockDioClient();
    mockDio = MockDio();
    when(() => mockDioClient.dio).thenReturn(mockDio);
    dataSource = FileRemoteDataSourceImpl(dioClient: mockDioClient);
  });

  group('FileRemoteDataSourceImpl listFiles', () {
    test('returns list of FileItemModel on 200 response', () async {
      when(() => mockDio.get(ApiConstants.listFilesEndpoint)).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiConstants.listFilesEndpoint),
            statusCode: 200,
            data: ['items.csv', 'catalog.png'],
          ));

      final result = await dataSource.listFiles();

      expect(result.length, 2);
      expect(result[0].name, 'items.csv');
      expect(result[1].name, 'catalog.png');
    });

    test('throws ServerException on non-200 response', () async {
      when(() => mockDio.get(ApiConstants.listFilesEndpoint)).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiConstants.listFilesEndpoint),
            statusCode: 500,
          ));

      expect(() => dataSource.listFiles(), throwsA(isA<ServerException>()));
    });
  });

  group('FileRemoteDataSourceImpl deleteFile', () {
    test('completes normally on 200 response', () async {
      when(() => mockDio.delete(
            ApiConstants.deleteEndpoint,
            queryParameters: {'file': 'item.csv'},
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiConstants.deleteEndpoint),
            statusCode: 200,
          ));

      await expectLater(dataSource.deleteFile('item.csv'), completes);
    });

    test('throws ServerException on 404 response', () async {
      when(() => mockDio.delete(
            ApiConstants.deleteEndpoint,
            queryParameters: {'file': 'missing.csv'},
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiConstants.deleteEndpoint),
            statusCode: 404,
          ));

      expect(() => dataSource.deleteFile('missing.csv'), throwsA(isA<ServerException>()));
    });
  });
}
