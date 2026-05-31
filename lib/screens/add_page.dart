import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/services/photo_service.dart';
import '../core/services/profile_service.dart';
import '../core/services/tattoo_request_service.dart';
import '../core/utils/pick_images.dart';
import '../l10n/app_localizations.dart';
import '../widgets/safe_media_renderer.dart';
import 'chat_page.dart';

/// Add tab: customer uploads reference photo, adds description and starting bid.
class AddPage extends StatefulWidget {
  const AddPage({
    super.key,
    required this.selectedExploreCountryNotifier,
    this.onRequestSubmitted,
    this.isArtistPromo = false,
  });

  /// Posts are tagged for this country (same as Explore filter).
  final ValueNotifier<String> selectedExploreCountryNotifier;

  /// Called after a request is successfully submitted (e.g. to switch to Explore).
  final VoidCallback? onRequestSubmitted;

  /// When true, shows promo copy for tattoo artists posting portfolio work.
  final bool isArtistPromo;

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _placementController = TextEditingController();
  final _sizeController = TextEditingController();
  final _startingBidController = TextEditingController();
  final _nextAvailabilityController = TextEditingController();

  String? _colourPreference; // 'colour' or 'black_and_grey'
  String? _timeframe; // 'asap', 'during_the_week', 'when_you_can_book_me_in'
  bool _artistCreativeFreedom = true;
  bool _uploading = false;
  bool _submitting = false;
  String? _errorMessage;
  String? _uploadedUrl;
  bool _showDetailsForm = false;
  bool _submitted = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _placementController.dispose();
    _sizeController.dispose();
    _startingBidController.dispose();
    _nextAvailabilityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (xFile == null || !mounted) return;

    final path = xFile.path;
    if (path.isEmpty) return;

    setState(() {
      _uploading = true;
      _errorMessage = null;
      _uploadedUrl = null;
      _showDetailsForm = false;
      _submitted = false;
    });
    try {
      final url = await PhotoService.uploadPhoto(File(path));
      if (!mounted) return;
      setState(() {
        _uploadedUrl = url;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _showPhotoOptions() async {
    final source = await showPhotoSourceBottomSheet(context);
    if (source == null || !mounted) return;
    await _pickImage(source);
  }

  void _startOver() {
    setState(() {
      _uploadedUrl = null;
      _showDetailsForm = false;
      _submitted = false;
      _descriptionController.clear();
      _placementController.clear();
      _sizeController.clear();
      _colourPreference = null;
      _timeframe = null;
      _artistCreativeFreedom = true;
      _startingBidController.clear();
      _nextAvailabilityController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _showCountryGuardDialog({
    required String title,
    required String body,
  }) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.addPostCountryMismatchOk),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate() || _uploadedUrl == null) return;

    final postCountry = widget.selectedExploreCountryNotifier.value.trim();
    if (postCountry.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      await _showCountryGuardDialog(
        title: l10n.addPostNeedDestinationTitle,
        body: l10n.addPostNeedDestinationBody,
      );
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final profile = await ProfileService.getCurrentProfile();
    if (!mounted) return;

    final profileCountry = profile?.country?.trim() ?? '';
    if (profileCountry.isEmpty) {
      setState(() => _submitting = false);
      final l10n = AppLocalizations.of(context)!;
      await _showCountryGuardDialog(
        title: l10n.addPostCountryMissingTitle,
        body: l10n.addPostCountryMissingBody,
      );
      return;
    }

    if (profileCountry != postCountry) {
      setState(() => _submitting = false);
      final l10n = AppLocalizations.of(context)!;
      await _showCountryGuardDialog(
        title: l10n.addPostCountryMismatchTitle,
        body: l10n.addPostCountryMismatchBody(postCountry),
      );
      return;
    }

    try {
      final startingBid =
          double.tryParse(_startingBidController.text.trim()) ?? 0.0;
      await TattooRequestService.createRequest(
        imageUrl: _uploadedUrl!,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        placement: widget.isArtistPromo
            ? (_nextAvailabilityController.text.trim().isEmpty
                ? null
                : _nextAvailabilityController.text.trim())
            : (_placementController.text.trim().isEmpty
                ? null
                : _placementController.text.trim()),
        size: widget.isArtistPromo
            ? null
            : (_sizeController.text.trim().isEmpty
                ? null
                : _sizeController.text.trim()),
        colourPreference: widget.isArtistPromo ? null : _colourPreference,
        artistCreativeFreedom:
            widget.isArtistPromo ? true : _artistCreativeFreedom,
        timeframe: widget.isArtistPromo ? null : _timeframe,
        startingBid: startingBid,
        country: postCountry,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
      widget.onRequestSubmitted?.call();
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = e.toString();
      });
      debugPrint('Submit request error: $e\n$st');
    }
  }

  void _openPromoChat() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ChatPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          widget.isArtistPromo ? l10n.addPromoTitle : l10n.tabUpload,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_uploading)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(l10n.addUploading),
                  ],
                )
              else if (_submitted)
                _buildSuccessState(context)
              else if (_showDetailsForm && _uploadedUrl != null)
                _buildDetailsForm(context)
              else if (_uploadedUrl != null)
                _buildPhotoPreview(context)
              else
                _buildInitialState(context),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Icon(
          Icons.add_a_photo,
          size: 80,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.addReferencePhotoTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.addReferencePhotoSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _showPhotoOptions,
          icon: const Icon(Icons.add),
          label: Text(l10n.addPhotoButton),
        ),
      ],
    );
  }

  Widget _buildPhotoPreview(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 280,
            height: 280,
            child: SafeMediaRenderer(url: _uploadedUrl!),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.addPhotoUploadedTitle,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.addPhotoUploadedSubtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => setState(() => _showDetailsForm = true),
          icon: const Icon(Icons.check_circle_outline),
          label: Text(l10n.addHappyAddDetails),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _showPhotoOptions,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.addChooseDifferentPhoto),
        ),
      ],
    );
  }

  Widget _buildDetailsForm(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 200,
              height: 200,
              child: SafeMediaRenderer(url: _uploadedUrl!),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.addDescriptionSectionTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: widget.isArtistPromo
                  ? l10n.addPromoFieldDescriptionLabel
                  : l10n.addFieldDescriptionLabel,
              hintText: widget.isArtistPromo ? null : l10n.addDescriptionHint,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.next,
          ),
          if (!widget.isArtistPromo) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _placementController,
              decoration: InputDecoration(
                labelText: l10n.addFieldPlacementLabel,
                hintText: l10n.addPlacementHint,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sizeController,
              decoration: InputDecoration(
                labelText: l10n.addFieldSizeLabel,
                hintText: l10n.addSizeHint,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.addSectionColourTitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: Text(l10n.addColourChip),
                  selected: _colourPreference == 'colour',
                  onSelected: (selected) {
                    setState(
                        () => _colourPreference = selected ? 'colour' : null);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(l10n.addBlackGreyChip),
                  selected: _colourPreference == 'black_and_grey',
                  onSelected: (selected) {
                    setState(() =>
                        _colourPreference = selected ? 'black_and_grey' : null);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.addSectionTimeframeTitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.addTimeAsap),
                  selected: _timeframe == 'asap',
                  onSelected: (selected) {
                    setState(() => _timeframe = selected ? 'asap' : null);
                  },
                ),
                ChoiceChip(
                  label: Text(l10n.addTimeWeek),
                  selected: _timeframe == 'during_the_week',
                  onSelected: (selected) {
                    setState(
                        () => _timeframe = selected ? 'during_the_week' : null);
                  },
                ),
                ChoiceChip(
                  label: Text(l10n.addTimeBookWhen),
                  selected: _timeframe == 'when_you_can_book_me_in',
                  onSelected: (selected) {
                    setState(() => _timeframe =
                        selected ? 'when_you_can_book_me_in' : null);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _artistCreativeFreedom,
              onChanged: (v) =>
                  setState(() => _artistCreativeFreedom = v ?? true),
              title: Text(
                l10n.addCreativeFreedomTitle,
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _startingBidController,
            decoration: InputDecoration(
              labelText: widget.isArtistPromo
                  ? l10n.addPromoStartingBidLabel
                  : l10n.addStartingBidLabel,
              hintText: l10n.addBidAmountHint,
              prefixText: '\$ ',
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            validator: (v) {
              final n = double.tryParse(v?.trim() ?? '');
              if (n == null || n < 0) {
                return l10n.addInvalidBidAmount;
              }
              return null;
            },
          ),
          if (widget.isArtistPromo) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _nextAvailabilityController,
              decoration: InputDecoration(
                labelText: l10n.addPromoNextAvailabilityLabel,
                hintText: l10n.addPromoNextAvailabilityHint,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openPromoChat,
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(l10n.addPromoChatButton),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submitRequest,
            child: _submitting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.addSubmitRequest),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _submitting
                ? null
                : () => setState(() => _showDetailsForm = false),
            child: Text(l10n.addBackButton),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Icon(
          Icons.check_circle,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.addSubmittedTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.addSubmittedSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _startOver,
          icon: const Icon(Icons.add),
          label: Text(l10n.addAnotherRequest),
        ),
      ],
    );
  }
}
