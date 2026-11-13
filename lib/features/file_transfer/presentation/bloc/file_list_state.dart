import 'package:equatable/equatable.dart';
import '../../domain/entities/file_item.dart';

abstract class FileListState extends Equatable {
  const FileListState();

  @override
  List<Object?> get props => [];
}

class FileListInitial extends FileListState {
  const FileListInitial();
}

class FileListLoading extends FileListState {
  const FileListLoading();
}

class FileListLoaded extends FileListState {
  final List<FileItem> files;

  const FileListLoaded(this.files);

  @override
  List<Object?> get props => [files];
}

class FileListError extends FileListState {
  final String message;

  const FileListError(this.message);

  @override
  List<Object?> get props => [message];
}
