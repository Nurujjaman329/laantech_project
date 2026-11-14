import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/transfer_task.dart';
import '../bloc/transfer_bloc.dart';
import '../bloc/transfer_event.dart';
import '../bloc/transfer_state.dart';
import '../widgets/transfer_item_tile.dart';

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
      final file = await FilePicker.pickFile(
        type: FileType.any,
      );

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
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  Future<void> _generateSample50MbFile() async {
    setState(() => _isGeneratingSample = true);
    try {
      final tempDir = Directory.systemTemp;
      final sampleFile = File('${tempDir.path}/catalog_sample_50mb.csv');
      final sink = sampleFile.openWrite();
      sink.writeln('id,sku,name,price,inventory_count,description,category');
      
      const row = '1001,SKU-PROD-001,Wireless Barcode Scanner,129.99,450,High speed 2D barcode scanner with Bluetooth for retail POS stations,Hardware\n';
      const targetBytes = 52428800; // 50MB
      final iterations = targetBytes ~/ row.length;
      for (int i = 0; i < iterations; i++) {
        sink.write(row);
      }
      await sink.flush();
      await sink.close();

      final actualSize = await sampleFile.length();
      setState(() {
        _selectedFilePath = sampleFile.path;
        _selectedFileName = 'catalog_sample_50mb.csv';
        _selectedFileSize = actualSize;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generated 50MB Catalog CSV for testing!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating sample file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingSample = false);
      }
    }
  }

  void _startUpload() {
    if (_selectedFilePath == null || _selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or generate a file first')),
      );
      return;
    }

    context.read<TransferBloc>().add(
          TransferUploadRequested(
            filePath: _selectedFilePath!,
            fileName: _selectedFileName!,
          ),
        );

    setState(() {
      _selectedFilePath = null;
      _selectedFileName = null;
      _selectedFileSize = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upload started in background')),
    );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalog & Media Upload'),
      ),
      body: BlocConsumer<TransferBloc, TransferState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final uploadTasks = state.allTasks
              .where((t) => t.type == TransferType.upload)
              .toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              // Picker Card
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.cloud_upload_outlined,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Upload File to POS Server',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Select CSV catalog, >50MB video/images, or generate a test file',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Selected File Preview
                        if (_selectedFileName != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.insert_drive_file_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedFileName!,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        _formatSize(_selectedFileSize ?? 0),
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () => setState(() {
                                    _selectedFilePath = null;
                                    _selectedFileName = null;
                                    _selectedFileSize = null;
                                  }),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Action Buttons: Pick File or Generate 50MB Sample
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickFile,
                                icon: const Icon(Icons.attach_file_rounded),
                                label: Text(_selectedFileName == null ? 'Pick File' : 'Change File'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isGeneratingSample ? null : _generateSample50MbFile,
                                icon: _isGeneratingSample
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(
                                        Icons.auto_awesome,
                                        color: AppColors.primary,
                                      ),
                                label: const Text('>50MB Sample'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_selectedFileName != null) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _startUpload,
                            icon: const Icon(Icons.upload_rounded),
                            label: const Text('Start Upload'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Active / Recent Uploads
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Upload History & Queue',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Badge.count(
                      count: uploadTasks.length,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      textColor: theme.colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),

              if (uploadTasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No uploads yet. Pick a file or generate a sample to begin.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                ...uploadTasks.map((task) => TransferItemTile(
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
                    )),
            ],
          );
        },
      ),
    );
  }
}
