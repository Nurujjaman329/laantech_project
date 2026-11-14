import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/upload_file_validator.dart';
import '../../../../core/widgets/pos_terminal_banner.dart';
import '../../domain/entities/transfer_task.dart';
import '../bloc/transfer_bloc.dart';
import '../bloc/transfer_event.dart';
import '../bloc/transfer_state.dart';
import '../utils/sample_catalog_generator.dart';
import '../widgets/section_header.dart';
import '../widgets/status_panel.dart';
import '../widgets/transfer_item_tile.dart';
import '../widgets/upload_picker_card.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String? _selectedFilePath;
  String? _selectedFileName;
  int? _selectedFileSize;
  bool _isGeneratingSample = false;

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.any);

      if (file != null && file.path != null) {
        setState(() {
          _selectedFilePath = file.path;
          _selectedFileName = file.name;
          _selectedFileSize = file.lengthSync();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick file: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _generateSample50MbFile() async {
    setState(() => _isGeneratingSample = true);
    try {
      final sampleFile = await SampleCatalogGenerator.generate();
      final actualSize = await sampleFile.length();

      setState(() {
        _selectedFilePath = sampleFile.path;
        _selectedFileName = SampleCatalogGenerator.defaultFileName;
        _selectedFileSize = actualSize;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generated 50MB catalog CSV for testing'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating sample file: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingSample = false);
      }
    }
  }

  Future<void> _startUpload() async {
    if (_selectedFilePath == null || _selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or generate a file first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final path = _selectedFilePath!;
    final name = _selectedFileName!;
    final file = File(path);
    final exists = await file.exists();
    final sizeBytes = exists ? await file.length() : (_selectedFileSize ?? 0);
    final validationError = UploadFileValidator.validate(
      exists: exists,
      sizeBytes: sizeBytes,
      maxBytes: ApiConstants.maxUploadBytes,
    );
    if (validationError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    context.read<TransferBloc>().add(
          TransferUploadRequested(
            filePath: path,
            fileName: name,
          ),
        );

    _clearSelection();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Upload queued in background'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedFilePath = null;
      _selectedFileName = null;
      _selectedFileSize = null;
    });
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double b = bytes.toDouble();
    while (b >= 1024 && i < suffixes.length - 1) {
      b /= 1024;
      i++;
    }
    return '${b.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalog import'),
      ),
      body: BlocBuilder<TransferBloc, TransferState>(
        builder: (context, state) {
          final uploadTasks = state.allTasks
              .where((t) => t.type == TransferType.upload)
              .toList();
          final activeCount = uploadTasks
              .where((t) => t.isRunning || t.isPaused || t.status == TransferStatus.queued)
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              PosTerminalBanner(
                title: 'Import station',
                subtitle: 'Push catalogs & media packs to the POS server',
                icon: Icons.cloud_upload_rounded,
                statusLabel: activeCount > 0 ? '$activeCount LIVE' : 'READY',
                online: true,
              ),
              const SizedBox(height: 12),
              if (activeCount > 0) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sync_rounded,
                        size: 18,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$activeCount active ${activeCount == 1 ? 'transfer' : 'transfers'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              UploadPickerCard(
                selectedFileName: _selectedFileName,
                selectedFileSize: _selectedFileSize,
                isGeneratingSample: _isGeneratingSample,
                onPickFile: _pickFile,
                onGenerateSample: _generateSample50MbFile,
                onStartUpload: _startUpload,
                onClearSelection: _clearSelection,
                formatSize: _formatSize,
              ),

              const SizedBox(height: 8),
              SectionHeader(
                title: 'Upload history & queue',
                count: uploadTasks.length,
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
              ),

              if (uploadTasks.isEmpty)
                const StatusPanel(
                  icon: Icons.cloud_upload_outlined,
                  title: 'No uploads yet',
                  message:
                      'Pick a file or generate a 50MB sample to begin importing.',
                  padding: EdgeInsets.fromLTRB(0, 8, 0, 16),
                )
              else
                ...uploadTasks.map(
                  (task) => TransferItemTile(
                    task: task,
                    onPause: () => context.read<TransferBloc>().add(
                          TransferPauseRequested(task.id),
                        ),
                    onResume: () => context.read<TransferBloc>().add(
                          TransferResumeRequested(task.id),
                        ),
                    onCancel: () => context.read<TransferBloc>().add(
                          TransferCancelRequested(task.id),
                        ),
                    onRetry: () => context.read<TransferBloc>().add(
                          TransferRetryRequested(task.id),
                        ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
