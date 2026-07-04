import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/loading_overlay.dart';
import '../../core/widgets/tab_header.dart';
import '../../services/product_lookup_service.dart';
import 'bloc/search_bloc.dart';
import 'bloc/search_event.dart';
import 'bloc/search_state.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();

  void _submit(BuildContext context) {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    context.read<SearchBloc>().add(SearchQuerySubmitted(query));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocConsumer<SearchBloc, SearchState>(
          listener: (context, state) {
            if (state is SearchAnalysisSuccess) {
              context.push('/result/${state.result.id}');
            }
          },
          builder: (context, state) {
            final isBusy = state is SearchSearching || state is SearchAnalyzing;
            return Column(
              children: [
                const TabHeader(title: 'Cari Produk'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSearchBar(context, isBusy),
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildBody(context, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isBusy) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: !isBusy,
            decoration: const InputDecoration(
              hintText: 'Cari nama produk...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onSubmitted: (_) => _submit(context),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: isBusy ? null : () => _submit(context),
          icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, SearchState state) {
    if (state is SearchSearching || state is SearchAnalyzing) {
      return Stack(
        children: [
          _buildEmptyState(),
          LoadingOverlay(
            message: state is SearchAnalyzing
                ? 'Menganalisis produk...'
                : 'Mencari produk...',
          ),
        ],
      );
    }
    if (state is SearchResultsFound) {
      return _buildResultsList(context, state.results);
    }
    if (state is SearchNotFound) {
      return _buildMessage(
        icon: Icons.search_off_rounded,
        color: AppColors.textHint,
        message:
            'Produk tidak ditemukan. Coba kata kunci lain, atau scan foto produknya langsung.',
      );
    }
    if (state is SearchError) {
      return _buildMessage(
        icon: Icons.error_outline_rounded,
        color: AppColors.dangerRed,
        message: state.message,
      );
    }
    return _buildEmptyState();
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Ketik nama produk yang ingin kamu cari — kami akan carikan info komposisinya.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(
      BuildContext context, List<ProductLookupResult> results) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final result = results[i];
        return AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              result.productName ?? 'Produk Tanpa Nama',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: result.brand != null ? Text(result.brand!) : null,
            trailing:
                const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
            onTap: () =>
                context.read<SearchBloc>().add(SearchResultPicked(result)),
          ),
        );
      },
    );
  }
}
