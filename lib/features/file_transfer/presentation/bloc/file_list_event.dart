import 'package:equatable/equatable.dart';

abstract class FileListEvent extends Equatable {
  const FileListEvent();

  @override
  List<Object?> get props => [];
}

class FileListFetchRequested extends FileListEvent {
  const FileListFetchRequested();
}

class FileListRefreshRequested extends FileListEvent {
  const FileListRefreshRequested();
}

class FileListDeleteRequested extends FileListEvent {
  final String fileName;
  const FileListDeleteRequested(this.fileName);

  @override
  List<Object?> get props => [fileName];
}
