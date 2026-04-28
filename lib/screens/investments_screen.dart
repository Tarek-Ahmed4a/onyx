import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/premium_empty_state.dart';
import '../widgets/custom_toast.dart';
import '../widgets/elite_header.dart';
import '../widgets/elite_card.dart';
import '../widgets/elite_dialog.dart';
import '../widgets/animated_amount.dart';
import '../widgets/connectivity_indicator.dart';
import '../widgets/elite_selection_sheet.dart';
import '../services/market_data_service.dart';
import '../models/mock_market_data.dart';
import 'profile_screen.dart';


const Map<String, String> knownFunds = {
  'NMF': 'صندوق NM أسهم شريعة',
  'CMS': 'صندوق مؤشر CI EGX33 الشريعة',
  'ASO': 'صندوق أزيموت فرص الشريعة',
  'BWA': 'صندوق بلتون وفرة',
  'ADA': 'صندوق الأهلي ذهب',
  'AZG': 'صندوق Azimut جولد',
  'BFA': 'صندوق بلتون فضة',
  'BSB': 'صندوق بلتون سبائك',
  'MTF': 'صندوق مصر للتأمين التكافلي',
};

const Map<String, String> knownStocks = {
  'AMER.CA': '(مجموعة عامر القابضة (عامر جروب',
  'ATLC.CA': 'A.T.LEASEالتوفيق للتأجير التمويلي -أية.تي.ليس',
  'TALM.CA': 'Taaleem Management Services تعليم لخدمات الإدارة',
  'ISPH.CA': 'ابن سينا فارما',
  'ABUK.CA': 'ابوقير للاسمدة والصناعات الكيماوية',
  'AIHC.CA': 'ارابيا انفستمنتس هولدنج',
  'AIDC.CA': 'ارابيا للاستثمار والتنمية',
  'ASPI.CA': 'اسباير كابيتال القابضة للاستثمارات المالية',
  'SCEM.CA': 'اسمنت سيناء',
  'ASCM.CA': 'اسيك للتعدين - اسكوم',
  'EMFD.CA': 'إعمار مصر للتنمية',
  'ACTF.CA': 'اكت فاينانشال للاستشارات',
  'ALCN.CA': 'الاسكندرية لتداول الحاويات والبضائع',
  'AMOC.CA': 'الاسكندرية للزيوت المعدنية',
  'IDRE.CA': 'الاسماعيلية الجديدة للتطوير والتنمية العمرانية-شركة منقسمة',
  'ISMA.CA': 'الاسماعيلية مصر للدواجن',
  'AFDI.CA': 'الاهلي للتنمية والاستثمار',
  'COMI.CA': 'البنك التجاري الدولي -مصر (سى اى بى )',
  'EXPA.CA': 'البنك المصري لتنمية الصادرات',
  'DAPH.CA': 'التعمير والاستشارات الهندسية',
  'ISMQ.CA': 'الحديد والصلب للمناجم والمحاجر',
  'ICFC.CA': 'الدولية للأسمدة والكيماويات',
  'IFAP.CA': 'الدوليه للمحاصيل الزراعيه',
  'ZEOT.CA': 'الزيوت المستخلصة ومنتجاتها',
  'OCDI.CA': 'السادس من اكتوبر للتنميه والاستثمار- سوديك',
  'SWDY.CA': 'السويدى اليكتريك',
  'EAST.CA': 'الشرقية - ايسترن كومباني',
  'ELSH.CA': 'الشمس للاسكان والتعمير',
  'UEGC.CA': 'الصعيد العامة للمقاولات والاستثمار العقاري SCCD',
  'EGCH.CA': 'الصناعات الكيماوية المصرية - كيما',
  'ENGC.CA': 'الصناعات الهندسية المعمارية للانشاء والتعمير - ايكون',
  'RMDA.CA': 'العاشر من رمضان للصناعات الدوائية والمستحضرات تشخيصية-راميدا',
  'PRCL.CA': 'العامة لمنتجات الخزف والصيني',
  'MEPA.CA': 'العبوات الطبية',
  'OBRI.CA': 'العبور للاستثمار العقارى',
  'ARCC.CA': 'العربية للاسمنت',
  'ECAP.CA': 'العز للسيراميك و البورسلين - الجوهره',
  'POUL.CA': 'القاهرة للدواجن',
  'COSG.CA': 'القاهرة للزيوت والصابون',
  'CCAP.CA': 'القلعة للاستثمارات المالية',
  'CSAG.CA': 'القناة للتوكيلات الملاحية',
  'IEEC.CA': 'المشروعات الصناعية والهندسية',
  'PHAR.CA': 'المصرية الدولية للصناعات الدوائية - ايبيكو',
  'ETRS.CA': 'المصرية لخدمات النقل (ايجيترانس)',
  'ETEL.CA': 'المصرية للاتصالات',
  'EGTS.CA': 'المصرية للمنتجعات السياحية',
  'MOED.CA': 'المصرية لنظم التعليم الحديثة',
  'MPRC.CA': 'المصريه لمدينة الانتاج الاعلامى',
  'EHDR.CA': 'المصريين للاسكان والتنمية والتعمير',
  'ARAB.CA': 'المطورون العرب القابضة',
  'AMIA.CA': 'الملتقي العربي للاستثمارات',
  'MPCO.CA': 'المنصورة للدواجن',
  'ORWE.CA': 'النساجون الشرقيون للسجاد',
  'KABO.CA': 'النصر للملابس والمنسوجات - كابو',
  'NIPH.CA': 'النيل للادوية والصناعات الكيماوية - النيل',
  'MTIE.CA': 'ام.ام جروب للصناعة والتجارة العالمية',
  'OFH.CA': 'او بي المالية القابضة',
  'ORAS.CA': 'اوراسكوم كونستراكشون بي ال سي',
  'OIH.CA': 'اوراسكوم للاستثمار القابضه',
  'ORHD.CA': 'اوراسكوم للتنمية مصر',
  'EFIH.CA': 'اي فاينانس للاستثمارات المالية والرقمية',
  'EFID.CA': 'ايديتا للصناعات الغذائية',
  'PHDC.CA': 'بالم هيلز للتعمير',
  'BTFH.CA': 'بلتون القابضة',
  'HDBK.CA': 'بنك التعمير والاسكان',
  'CIEB.CA': 'بنك كريدي اجريكول مصر',
  'TANM.CA': 'تنمية للاستثمار العقاري',
  'BIOC.CA': 'جلاكسو سميثكلاين',
  'SVCE.CA': 'جنوب الوادى للاسمنت',
  'JUFO.CA': 'جهينة للصناعات الغذائية',
  'GPIM.CA': 'جى بى اى للنمو العمرانى',
  'GBCO.CA': 'جى بى كوربوريشن',
  'DSCW.CA': 'دايس للملابس الجاهزة',
  'RAYA.CA': 'راية القابضة للأستثمارات المالية',
  'RACC.CA': 'راية لخدمات مراكز الاتصالات',
  'ZMID.CA': 'زهراء المعادي للاستثمار والتعمير',
  'SIPC.CA': 'سبأ الدولية للأدوية والصناعات الكيماوية',
  'SKPC.CA': 'سيدى كرير للبتروكيماويات - سيدبك',
  'SDTI.CA': 'شارم دريمز للاستثمار السياحى',
  'NCCW.CA': 'شركة النصر للأعمال المدنية',
  'TAQA.CA': 'طاقة عربية',
  'VLMR.CA': 'فالمور القابضة للاستثمار',
  'VLMRA.CA': 'فالمور القابضة للاستثماربالجنية',
  'FWRY.CA': 'فوري لتكنولوجيا البنوك والمدفوعات الالكترونية',
  'CNFN.CA': 'كونتكت المالية القابضة',
  'LCSW.CA': 'ليسيكو مصر',
  'MCRO.CA': 'ماكرو جروب للمستحضرات الطبية-ماكرو كابيتال',
  'HRHO.CA': 'مجموعة اي اف جي القابضة',
  'TMGH.CA': 'مجموعة طلعت مصطفى القابضة',
  'MASR.CA': 'مدينة مصر للاسكان والتعمير',
  'HELI.CA': 'مصر الجديدة للاسكان والتعمير',
  'ATQA.CA': 'مصر الوطنية للصلب - عتاقة',
  'MFPC.CA': 'مصر لإنتاج الأسمدة - موبكو',
  'MCQE.CA': 'مصر للاسمنت - قنا',
  'EGAL.CA': 'مصر للالومنيوم',
  'ADIB.CA': 'مصرف أبو ظبي الأسلامي- مصر',
  'AFMC.CA': 'مطاحن ومخابز الاسكندرية',
  'MPCI.CA': 'ممفيس للادوية والصناعات الكيماوية',
  'KRDI.CA': 'نهر الخير للتنمية والأستثمار الزراعى والخدمات البيئية',
  'VALU.CA': 'يو للتمويل الاستهلاكى',
  'UNIP.CA': 'يونيفرسال لصناعة مواد التعبئة و التغليف و الورق - يونيباك',
};

class Asset {
  final String id;
  String name;
  double buyPrice;
  double currentPrice;
  double quantity;
  String? fcmToken;
  double? takeProfit;
  double? stopLoss;

  Asset({
    required this.id,
    required this.name,
    required this.buyPrice,
    required this.currentPrice,
    required this.quantity,
    this.fcmToken,
    this.takeProfit,
    this.stopLoss,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'buyPrice': buyPrice,
        'currentPrice': currentPrice,
        'quantity': quantity,
        'fcmToken': fcmToken,
        'takeProfit': takeProfit,
        'stopLoss': stopLoss,
      };

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
        id: json['id'],
        name: json['name'],
        buyPrice: (json['buyPrice'] as num).toDouble(),
        currentPrice: (json['currentPrice'] as num?)?.toDouble() ??
            (json['buyPrice'] as num).toDouble(),
        quantity: (json['quantity'] as num).toDouble(),
        fcmToken: json['fcmToken'] as String?,
        takeProfit: (json['takeProfit'] as num?)?.toDouble(),
        stopLoss: (json['stopLoss'] as num?)?.toDouble(),
      );
}

class Portfolio {
  final String id;
  String name;
  List<Asset> assets;
  double balance;
  double initialBudget;

  Portfolio({
    required this.id,
    required this.name,
    List<Asset>? assets,
    this.balance = 0.0,
    this.initialBudget = 0.0,
  }) : assets = assets ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'assets': assets.map((a) => a.toJson()).toList(),
        'balance': balance,
        'initialBudget': initialBudget,
      };

  factory Portfolio.fromJson(Map<String, dynamic> json) => Portfolio(
        id: json['id'],
        name: json['name'],
        assets: (json['assets'] as List<dynamic>?)
                ?.map((item) => Asset.fromJson(item))
                .toList() ??
            [],
        balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
        initialBudget: (json['initialBudget'] as num?)?.toDouble() ?? 0.0,
      );
}

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen>
    with TickerProviderStateMixin {
  List<Portfolio> _portfolios = [];
  String? _activePortfolioId;
  bool _isLoading = true;
  StreamSubscription? _portfoliosSub;
  late TabController _tabController;

  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, Future<QuerySnapshot>> _historyFutures = {};

  @override
  void dispose() {
    _portfoliosSub?.cancel();
    _tabController.dispose();
    for (var controller in _qtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. Load from local storage FIRST (instant, offline-safe)
      await _loadLocalPortfolios();

      // 2. Try Firestore as optional sync
      await _createDefaultPortfolioIfMissing();
      _loadPortfolios();

      // Fetch initial market data if not already loaded
      if (mounted) {
        final marketDataService = context.read<MarketDataService>();
        if (!marketDataService.hasData) {
          marketDataService.fetchAllMarketData();
        }
      }
    } catch (e) {
      debugPrint('Investment Init Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Load portfolios from SharedPreferences (local offline storage)
  Future<void> _loadLocalPortfolios() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('local_portfolios');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonStr);
        final loaded = jsonList.map((item) => Portfolio.fromJson(item)).toList();
        if (loaded.isNotEmpty && mounted) {
          setState(() {
            _portfolios = loaded;
            if (_activePortfolioId == null ||
                !_portfolios.any((p) => p.id == _activePortfolioId)) {
              _activePortfolioId = _portfolios.first.id;
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading local portfolios: $e');
    }
  }

  /// Save portfolios to SharedPreferences for offline persistence
  Future<void> _savePortfoliosLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(_portfolios.map((p) => p.toJson()).toList());
      await prefs.setString('local_portfolios', jsonStr);
    } catch (e) {
      debugPrint('Error saving local portfolios: $e');
    }
  }

  Future<void> _createDefaultPortfolioIfMissing() async {
    final uid = (FirebaseAuth.instance.currentUser?.uid ?? 'guest_user');

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('investments');

    try {
      final snapshot = await collection.get();
      if (snapshot.docs.isEmpty) {
        final defaultPortfolio = Portfolio(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Main Profile',
          balance: 0.0,
          initialBudget: 0.0,
        );
        await collection
            .doc(defaultPortfolio.id)
            .set(defaultPortfolio.toJson());
      }
    } catch (e) {
      debugPrint('Error creating default portfolio: $e');
    }
  }

  Future<void> _loadPortfolios() async {
    final uid = (FirebaseAuth.instance.currentUser?.uid ?? 'guest_user');

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('investments');

    try {
      // Start reactive stream for live updates
      _portfoliosSub = collection.snapshots().listen(
        (QuerySnapshot<Map<String, dynamic>> snapshot) {
          final loadedPortfolios = snapshot.docs
              .map((doc) => Portfolio.fromJson(doc.data()))
              .toList();

          if (mounted) {
            setState(() {
              if (loadedPortfolios.isNotEmpty) {
                _portfolios = loadedPortfolios;
              }
              // Only set fallback if portfolios is still empty
              if (_portfolios.isEmpty) {
                _portfolios = [
                  Portfolio(
                    id: 'guest_fallback_id',
                    name: 'Main Profile',
                    balance: 10000.0,
                    initialBudget: 10000.0,
                    assets: [],
                  )
                ];
              }
              if (_activePortfolioId == null ||
                  !_portfolios.any((p) => p.id == _activePortfolioId)) {
                _activePortfolioId = _portfolios.first.id;
              }
              _isLoading = false;
            });
          }
        },
        onError: (e) {
          debugPrint('Firestore Error loading portfolios: $e');
          if (mounted) {
            setState(() {
              // Create fallback on error (e.g. permission denied for guest)
              if (_portfolios.isEmpty) {
                _portfolios = [
                  Portfolio(
                    id: 'guest_fallback_id',
                    name: 'Main Profile',
                    balance: 10000.0,
                    initialBudget: 10000.0,
                    assets: [],
                  )
                ];
                _activePortfolioId = _portfolios.first.id;
              }
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error initializing portfolios: $e');
      if (mounted) {
        setState(() {
          if (_portfolios.isEmpty) {
            _portfolios = [
              Portfolio(
                id: 'guest_fallback_id',
                name: 'Main Profile',
                balance: 10000.0,
                initialBudget: 10000.0,
                assets: [],
              )
            ];
            _activePortfolioId = _portfolios.first.id;
          }
          _isLoading = false;
        });
      }
    }
  }

  void _showNewPortfolioDialog() {
    final controller = TextEditingController();
    EliteDialog.show(
      context: context,
      title: 'New Portfolio',
      glowColor: Colors.black,
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: 'PORTFOLIO NAME',
          labelStyle: const TextStyle(
              fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w900, color: Colors.black54),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: Colors.black54)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.black),
          onPressed: () {
            _addPortfolio(controller.text);
            Navigator.pop(context);
          },
          child: const Text('CREATE', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _addPortfolio(String name) async {
    if (name.isEmpty) return;
    final newPortfolio = Portfolio(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      balance: 0.0,
      initialBudget: 0.0,
    );

    // Update UI immediately
    if (mounted) {
      setState(() {
        _portfolios.add(newPortfolio);
        _activePortfolioId = newPortfolio.id;
      });
    }
    await _savePortfoliosLocally();

    // Background sync to Firestore
    try {
      final uid = (FirebaseAuth.instance.currentUser?.uid ?? 'guest_user');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('investments')
          .doc(newPortfolio.id)
          .set(newPortfolio.toJson());
    } catch (e) {
      debugPrint('Firestore sync error (non-blocking): $e');
    }
  }
  void _deletePortfolio(Portfolio portfolio) {
    if (_portfolios.length <= 1) {
      CustomToast.show(
        context: context,
        message: 'Cannot delete the last profile.',
        icon: Icons.warning_amber_rounded,
        color: Colors.orangeAccent,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: Text(
            'Are you sure you want to delete "${portfolio.name}" and all its assets?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Update UI immediately
              setState(() {
                _portfolios.removeWhere((p) => p.id == portfolio.id);
                if (_activePortfolioId == portfolio.id) {
                  _activePortfolioId = _portfolios.first.id;
                }
              });
              _savePortfoliosLocally();
              // Background sync
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid ?? 'guest_user')
                  .collection('investments')
                  .doc(portfolio.id)
                  .delete()
                  .catchError((e) => debugPrint('Delete sync error: $e'));
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _addAsset(String name, double buyPrice, double currentPrice,
      double quantity, double? takeProfit, double? stopLoss) async {
    if (_activePortfolioId == null) return;
    final activePortfolio =
        _portfolios.firstWhere((p) => p.id == _activePortfolioId);

    final totalCost = buyPrice * quantity;
    if (totalCost > activePortfolio.balance) {
      if (mounted) {
        CustomToast.show(
          context: context,
          message: 'Insufficient balance to add this asset',
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFFFF3B30),
        );
      }
      return;
    }

    activePortfolio.balance -= totalCost;

    String? token;
    try {
      token = await FirebaseMessaging.instance.getToken();
    } catch (_) {}

    final newAsset = Asset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      buyPrice: buyPrice,
      currentPrice: currentPrice,
      quantity: quantity,
      fcmToken: token,
      takeProfit: takeProfit,
      stopLoss: stopLoss,
    );

    activePortfolio.assets.add(newAsset);

    // Update UI immediately
    if (mounted) {
      setState(() {});
      HapticFeedback.lightImpact();
      CustomToast.show(
        context: context,
        message: 'Asset "${newAsset.name}" added',
        icon: Icons.check_circle_outline,
        color: const Color(0xFF34C759),
      );
    }
    await _savePortfoliosLocally();

    // Background sync to Firestore
    try {
      final uid = (FirebaseAuth.instance.currentUser?.uid ?? 'guest_user');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('investments')
          .doc(activePortfolio.id)
          .set(activePortfolio.toJson());
    } catch (e) {
      debugPrint('Firestore sync error (non-blocking): $e');
    }
  }

  void _showAddAssetDialog() {
    final nameController = TextEditingController();
    final buyPriceController = TextEditingController();
    final currentPriceController = TextEditingController();
    final quantityController = TextEditingController();
    final takeProfitController = TextEditingController();
    final stopLossController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Build combined map from MockMarketData (stocks + funds)
    final Map<String, Map<String, dynamic>> allAssets = {};
    for (final s in MockMarketData.egyptStocks) {
      allAssets[s.symbol] = {'name': s.name, 'price': s.price};
    }
    for (final f in MockMarketData.egyptFunds) {
      allAssets[f.symbol] = {'name': f.name, 'price': f.price};
    }
    for (final s in MockMarketData.saudiStocks) {
      allAssets[s.symbol] = {'name': s.name, 'price': s.price};
    }

    EliteDialog.show(
      context: context,
      title: 'Acquire Asset',
      glowColor: Colors.black,
      content: StatefulBuilder(builder: (context, setDialogState) {
        return Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final result = await EliteSelectionSheet.show<String>(
                    context: context,
                    title: 'Select Asset Ticker',
                    items: allAssets.keys.toList(),
                    labelBuilder: (ticker) => ticker,
                    subtitleBuilder: (ticker) =>
                        allAssets[ticker]?['name'] ?? '',
                    allowCustomEntry: false,
                    selectedItem: nameController.text.isNotEmpty
                        ? nameController.text
                        : null,
                  );
                  if (result != null) {
                    setDialogState(() {
                      nameController.text = result;
                      final price = allAssets[result]?['price'];
                      if (price != null) {
                        currentPriceController.text = price.toString();
                        buyPriceController.text = price.toString();
                      }
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 20, color: Colors.black54),
                      const SizedBox(width: 12),
                      Text(
                        nameController.text.isEmpty
                            ? 'SELECT ASSET TICKER'
                            : nameController.text,
                        style: TextStyle(
                          color: nameController.text.isEmpty
                              ? Colors.black54
                              : Colors.black,
                          fontWeight: nameController.text.isEmpty
                              ? FontWeight.normal
                              : FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down, color: Colors.black54),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: buyPriceController,
                      decoration: InputDecoration(
                        labelText: 'BUY PRICE',
                        labelStyle: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: quantityController,
                      decoration: InputDecoration(
                        labelText: 'QUANTITY',
                        labelStyle: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: currentPriceController,
                decoration: InputDecoration(
                  labelText: 'CURRENT MARKET PRICE',
                  labelStyle: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w900),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: takeProfitController,
                      decoration: InputDecoration(
                        labelText: 'TARGET PRICE',
                        labelStyle: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: stopLossController,
                      decoration: InputDecoration(
                        labelText: 'STOP LOSS',
                        labelStyle: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              _addAsset(
                nameController.text.toUpperCase(),
                double.parse(buyPriceController.text),
                double.parse(currentPriceController.text),
                double.parse(quantityController.text),
                double.tryParse(takeProfitController.text),
                double.tryParse(stopLossController.text),
              );
              Navigator.pop(context);
            }
          },
          child: const Text('SAVE'),
        ),
      ],
    );
  }

  void _updateAsset(
      Asset oldAsset,
      String name,
      double buyPrice,
      double currentPrice,
      double quantity,
      double? takeProfit,
      double? stopLoss) async {
    if (_activePortfolioId == null) return;
    final activePortfolio =
        _portfolios.firstWhere((p) => p.id == _activePortfolioId);

    final index = activePortfolio.assets.indexWhere((a) => a.id == oldAsset.id);
    if (index == -1) return;

    activePortfolio.assets[index] = Asset(
      id: oldAsset.id,
      name: name.trim(),
      buyPrice: buyPrice,
      currentPrice: currentPrice,
      quantity: quantity,
      fcmToken: oldAsset.fcmToken,
      takeProfit: takeProfit,
      stopLoss: stopLoss,
    );

    // Update UI immediately + persist locally
    if (mounted) {
      setState(() {});
      HapticFeedback.lightImpact();
      CustomToast.show(
        context: context,
        message: 'Asset "${name.trim()}" updated',
        icon: Icons.check_circle_outline,
        color: const Color(0xFF34C759),
      );
    }
    await _savePortfoliosLocally();

    // Background Firestore sync
    try {
      final uid = (FirebaseAuth.instance.currentUser?.uid ?? 'guest_user');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('investments')
          .doc(activePortfolio.id)
          .set(activePortfolio.toJson());
    } catch (e) {
      debugPrint('Firestore sync error (non-blocking): $e');
    }
  }

  void _showEditAssetDialog(Asset asset) {
    final nameController = TextEditingController(text: asset.name);
    final buyPriceController =
        TextEditingController(text: asset.buyPrice.toString());
    final currentPriceController =
        TextEditingController(text: asset.currentPrice.toString());
    final quantityController =
        TextEditingController(text: asset.quantity.toString());
    final takeProfitController =
        TextEditingController(text: asset.takeProfit?.toString() ?? '');
    final stopLossController =
        TextEditingController(text: asset.stopLoss?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    final marketData = context.read<MarketDataService>().stocksData;

    EliteDialog.show(
      context: context,
      title: 'Modify Asset',
      glowColor: Theme.of(context).colorScheme.primary,
      content: StatefulBuilder(builder: (context, setDialogState) {
        return Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final result = await EliteSelectionSheet.show<String>(
                    context: context,
                    title: 'Select Asset Ticker',
                    items: marketData.keys.toList(),
                    labelBuilder: (ticker) => ticker,
                    subtitleBuilder: (ticker) =>
                        marketData[ticker]?['name'] ?? '',
                    allowCustomEntry: true,
                    selectedItem: nameController.text.isNotEmpty
                        ? nameController.text
                        : null,
                  );
                  if (result != null) {
                    setDialogState(() {
                      nameController.text = result;
                      final price = marketData[result]?['price'];
                      if (price != null) {
                        currentPriceController.text = price.toString();
                      }
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 20, color: Colors.black54),
                      const SizedBox(width: 12),
                      Text(
                        nameController.text.isEmpty
                            ? 'SELECT ASSET TICKER'
                            : nameController.text,
                        style: TextStyle(
                          color: nameController.text.isEmpty
                              ? Colors.black54
                              : Colors.black,
                          fontWeight: nameController.text.isEmpty
                              ? FontWeight.normal
                              : FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down, color: Colors.black54),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: buyPriceController,
                      decoration: InputDecoration(
                        labelText: 'BUY PRICE',
                        labelStyle: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: quantityController,
                      decoration: InputDecoration(
                        labelText: 'QUANTITY',
                        labelStyle: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: currentPriceController,
                decoration: InputDecoration(
                  labelText: 'CURRENT MARKET PRICE',
                  labelStyle: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w900),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: takeProfitController,
                      decoration: InputDecoration(
                        labelText: 'TARGET PRICE',
                        labelStyle: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: stopLossController,
                      decoration: InputDecoration(
                        labelText: 'STOP LOSS',
                        labelStyle: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              _updateAsset(
                asset,
                nameController.text.toUpperCase(),
                double.parse(buyPriceController.text),
                double.parse(currentPriceController.text),
                double.parse(quantityController.text),
                double.tryParse(takeProfitController.text),
                double.tryParse(stopLossController.text),
              );
              Navigator.pop(context);
            }
          },
          child: const Text('SAVE'),
        ),
      ],
    );
  }

  void _deleteAsset(Asset asset) async {
    if (_activePortfolioId == null) return;
    final activePortfolio =
        _portfolios.firstWhere((p) => p.id == _activePortfolioId);

    // Refund the initial cost to the balance
    final refundAmount = asset.buyPrice * asset.quantity;
    activePortfolio.balance += refundAmount;
    activePortfolio.assets.remove(asset);

    // Update UI immediately + persist locally
    if (mounted) {
      setState(() {});
      HapticFeedback.lightImpact();
      CustomToast.show(
        context: context,
        message: 'Asset removed — EGP ${refundAmount.toStringAsFixed(2)} refunded',
        icon: Icons.undo_rounded,
        color: const Color(0xFF34C759),
      );
    }
    await _savePortfoliosLocally();

    // Background Firestore sync
    try {
      final uid = (FirebaseAuth.instance.currentUser?.uid ?? 'guest_user');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('investments')
          .doc(activePortfolio.id)
          .set(activePortfolio.toJson());
    } catch (e) {
      debugPrint('Firestore sync error (non-blocking): $e');
    }
  }

  void _handleSell(String ticker, double qty, double price) async {
    if (_activePortfolioId == null || qty <= 0) return;
    final activePortfolio =
        _portfolios.firstWhere((p) => p.id == _activePortfolioId);

    final existingIndex =
        activePortfolio.assets.indexWhere((a) => a.name == ticker);
    if (existingIndex == -1 ||
        activePortfolio.assets[existingIndex].quantity < qty) {
      CustomToast.show(
        context: context,
        message: 'Not enough shares to sell',
        icon: Icons.warning_amber_rounded,
        color: Colors.orangeAccent,
      );
      return;
    }

    final oldAsset = activePortfolio.assets[existingIndex];
    activePortfolio.balance += qty * price;

    if (oldAsset.quantity == qty) {
      activePortfolio.assets.removeAt(existingIndex);
    } else {
      activePortfolio.assets[existingIndex] = Asset(
        id: oldAsset.id,
        name: oldAsset.name,
        buyPrice: oldAsset.buyPrice,
        currentPrice: price,
        quantity: oldAsset.quantity - qty,
        fcmToken: oldAsset.fcmToken,
        takeProfit: oldAsset.takeProfit,
        stopLoss: oldAsset.stopLoss,
      );
    }

    await _syncPortfolio(activePortfolio);
  }

  Future<void> _syncPortfolio(Portfolio portfolio) async {
    // Update UI immediately
    if (mounted) setState(() {});

    // Persist locally
    await _savePortfoliosLocally();

    // Background sync to Firestore
    try {
      final uid = (FirebaseAuth.instance.currentUser?.uid ?? 'guest_user');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('investments')
          .doc(portfolio.id)
          .set(portfolio.toJson());
    } catch (e) {
      debugPrint('Firestore sync error (non-blocking): $e');
    }
  }

  void _showUpdateBudgetDialog(Portfolio portfolio) {
    final controller =
        TextEditingController(text: portfolio.initialBudget.toString());
    EliteDialog.show(
      context: context,
      title: 'Update Cash Balance',
      glowColor: Colors.black,
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: 'CASH (EGP)',
          labelStyle: const TextStyle(
              fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w900, color: Colors.black54),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: Colors.black54)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.black),
          onPressed: () async {
            final newBudget = double.tryParse(controller.text) ?? 0.0;
            if (newBudget == 0) {
              portfolio.initialBudget = 0.0;
              portfolio.balance = 0.0;
            } else {
              // If user increases budget, add the difference to balance
              final diff = newBudget - portfolio.initialBudget;
              portfolio.initialBudget = newBudget;
              portfolio.balance += diff;
            }
            await _syncPortfolio(portfolio);
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('UPDATE', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _showSellActionDialog(Asset asset, double livePrice) {
    final controller = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sell ${asset.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Quantity'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final qty = double.tryParse(controller.text) ?? 0;
              _handleSell(asset.name, qty, livePrice);
              Navigator.pop(context);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    if (_isLoading) {
      return ListView.builder(
        itemCount: 4,
        padding: const EdgeInsets.only(top: 80, left: 20, right: 20),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.white.withValues(alpha: 0.05),
            child: Container(
              height:
                  index == 0 ? 220 : 120, // First card is bigger (dashboard)
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          );
        },
      );
    }

    final activePortfolio = _portfolios.isEmpty
        ? null
        : _portfolios.firstWhere(
            (p) => p.id == _activePortfolioId,
            orElse: () => _portfolios.first,
          );

    double portfolioValue = 0;
    double totalPnlEgp = 0;
    double totalPnlPercent = 0;

    final marketData = Provider.of<MarketDataService>(context).stocksData;

    if (activePortfolio != null) {
      for (var asset in activePortfolio.assets) {
        final priceVal = marketData[asset.name]?['price'];
        final livePrice =
            (priceVal is num) ? priceVal.toDouble() : asset.currentPrice;
        portfolioValue += livePrice * asset.quantity;
      }

      final currentTotalValue = activePortfolio.balance + portfolioValue;
      totalPnlEgp = currentTotalValue - activePortfolio.initialBudget;
      if (activePortfolio.initialBudget > 0) {
        totalPnlPercent = (totalPnlEgp / activePortfolio.initialBudget) * 100;
      }
    }

    final portfolioSelector = SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _portfolios.length + 1,
        itemBuilder: (context, index) {
          if (index == _portfolios.length) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('New'),
                onPressed: () => _showNewPortfolioDialog(),
                backgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            );
          }

          final portfolio = _portfolios[index];
          final isActive = portfolio.id == _activePortfolioId;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onLongPress: () => _deletePortfolio(portfolio),
              child: ChoiceChip(
                label: Text(portfolio.name),
                selected: isActive,
                selectedColor:
                    Theme.of(context).colorScheme.primary.withAlpha(51),
                backgroundColor: Theme.of(context).cardColor,
                labelStyle: TextStyle(
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _activePortfolioId = portfolio.id;
                    });
                  }
                },
              ),
            ),
          );
        },
      ),
    );

    final myPortfolioView = Column(
      children: [
        portfolioSelector,
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
            children: [
              if (activePortfolio != null) ...[
                // Redesigned Premium Glass/Gradient Summary Card
                EliteCard(
                  glowColor:
                      totalPnlEgp >= 0 ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                _showUpdateBudgetDialog(activePortfolio),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'BUYING POWER (CASH)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '+ ADD',
                                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                AnimatedAmount(
                                  value: activePortfolio.balance,
                                  prefix: 'EGP ',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (totalPnlEgp >= 0
                                          ? const Color(0xFF34C759)
                                          : const Color(0xFFFF3B30))
                                      .withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: AnimatedAmount(
                                  value: totalPnlPercent,
                                  prefix: totalPnlPercent >= 0 ? '+' : '',
                                  suffix: '%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: totalPnlEgp >= 0
                                        ? const Color(0xFF34C759)
                                        : const Color(0xFFFF3B30),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedAmount(
                                value: totalPnlEgp,
                                prefix: 'EGP ${totalPnlEgp >= 0 ? '+' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: totalPnlEgp >= 0
                                      ? const Color(0xFF34C759)
                                      : const Color(0xFFFF3B30),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'PORTFOLIO VALUE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedAmount(
                        value: portfolioValue,
                        prefix: 'EGP ',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 100,
                        child: FutureBuilder<QuerySnapshot>(
                          future: _historyFutures.putIfAbsent(
                            activePortfolio.id,
                            () => FirebaseFirestore.instance
                                .collection('users')
                                .doc((FirebaseAuth.instance.currentUser?.uid ?? 'guest_user'))
                                .collection('investments')
                                .doc(activePortfolio.id)
                                .collection('portfolio_snapshots')
                                .orderBy('timestamp', descending: true)
                                .limit(14) // Fetch last 2 weeks for trend
                                .get(const GetOptions(source: Source.serverAndCache)),
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Shimmer.fromColors(
                                baseColor: Colors.grey.shade200,
                                highlightColor: Colors.grey.shade100,
                                child: Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              );
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              // Return mock chart for visual instead of empty text
                              final List<FlSpot> mockSpots = [
                                const FlSpot(0, 100),
                                const FlSpot(1, 105),
                                const FlSpot(2, 102),
                                const FlSpot(3, 108),
                                const FlSpot(4, 115),
                                const FlSpot(5, 110),
                                const FlSpot(6, 120),
                              ];
                              return LineChart(
                                LineChartData(
                                  gridData: const FlGridData(show: false),
                                  titlesData: const FlTitlesData(show: false),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: mockSpots,
                                      isCurved: true,
                                      color: Colors.black,
                                      barWidth: 3,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: Colors.black.withValues(alpha: 0.05),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Reverse snapshots to get chronological order [Oldest -> Newest]
                            final docs = snapshot.data!.docs.reversed.toList();
                            final List<FlSpot> spots = [];

                            for (int i = 0; i < docs.length; i++) {
                              final data =
                                  docs[i].data() as Map<String, dynamic>;
                              final val = data['total_value'];
                              if (val is num) {
                                spots.add(FlSpot(i.toDouble(), val.toDouble()));
                              }
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              // Return mock chart for visual instead of empty text
                              final List<FlSpot> mockSpots = [
                                const FlSpot(0, 100),
                                const FlSpot(1, 105),
                                const FlSpot(2, 102),
                                const FlSpot(3, 108),
                                const FlSpot(4, 115),
                                const FlSpot(5, 110),
                                const FlSpot(6, 120),
                              ];
                              return LineChart(
                                LineChartData(
                                  gridData: const FlGridData(show: false),
                                  titlesData: const FlTitlesData(show: false),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: mockSpots,
                                      isCurved: true,
                                      color: Colors.black,
                                      barWidth: 3,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: Colors.black.withValues(alpha: 0.05),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final lineColor = totalPnlEgp >= 0
                                ? const Color(0xFF34C759)
                                : const Color(0xFFFF3B30);

                            return LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: false),
                                titlesData: const FlTitlesData(show: false),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: true,
                                    color: lineColor,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          lineColor.withValues(alpha: 0.05),
                                          lineColor.withValues(alpha: 0.05),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                lineTouchData: LineTouchData(
                                  touchTooltipData: LineTouchTooltipData(
                                    getTooltipColor: (_) =>
                                        Colors.black.withValues(alpha: 0.05),
                                    getTooltipItems: (touchedSpots) {
                                      return touchedSpots.map((spot) {
                                        return LineTooltipItem(
                                          'EGP ${spot.y.toStringAsFixed(2)}',
                                          const TextStyle(
                                            color: Colors.black,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      }).toList();
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 64),
                const Center(
                  child: Text(
                    'No profiles found.',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Create a profile to start tracking your assets.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 12.0),
                child: Text(
                  'YOUR ASSETS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              if (activePortfolio != null && activePortfolio.assets.isNotEmpty)
                ...activePortfolio.assets.map((asset) {
                  final livePrice =
                      (marketData[asset.name]?['price'] as num?)?.toDouble() ??
                          asset.currentPrice;
                  final assetRoi =
                      ((livePrice - asset.buyPrice) / asset.buyPrice) * 100;
                  final assetProfitEgp =
                      (livePrice - asset.buyPrice) * asset.quantity;

                  return Dismissible(
                    key: Key(asset.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child:
                          const Icon(Icons.delete_outline, color: Colors.black),
                    ),
                    onDismissed: (_) => _deleteAsset(asset),
                    child: EliteCard(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      knownFunds[asset.name] ??
                                          knownStocks[asset.name] ??
                                          asset.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              asset.name,
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Qty: ${asset.quantity}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextButton(
                                              onPressed: () =>
                                                  _showSellActionDialog(
                                                      asset, livePrice),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    const Color(0xFFFF3B30),
                                                padding: EdgeInsets.zero,
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                              child: const Text('SELL',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 20,
                                                  color: Colors.blueAccent),
                                              onPressed: () =>
                                                  _showEditAssetDialog(asset),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Divider(color: Colors.grey.shade200, height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _buildAssetDetail('BUY AVG',
                                    'EGP ${asset.buyPrice.toStringAsFixed(2)}'),
                              ),
                              Expanded(
                                child: _buildAssetDetail('LIVE PRICE',
                                    'EGP ${livePrice.toStringAsFixed(2)}',
                                    color: assetRoi >= 0
                                        ? const Color(0xFF34C759)
                                        : const Color(0xFFFF3B30)),
                              ),
                              Expanded(
                                child: _buildAssetDetail('ROI',
                                    'EGP ${assetProfitEgp >= 0 ? '+' : ''}${assetProfitEgp.toStringAsFixed(1)} (${assetRoi >= 0 ? '+' : ''}${assetRoi.toStringAsFixed(1)}%)',
                                    color: assetRoi >= 0
                                        ? const Color(0xFF34C759)
                                        : const Color(0xFFFF3B30)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _buildAssetDetail(
                                    'TARGET (TP)',
                                    asset.takeProfit != null
                                        ? 'EGP ${asset.takeProfit!.toStringAsFixed(2)}'
                                        : 'N/A',
                                    color: const Color(0xFF34C759)),
                              ),
                              Expanded(
                                child: _buildAssetDetail('TOTAL',
                                    'EGP ${(asset.buyPrice * asset.quantity).toStringAsFixed(2)}',
                                    color: Colors.black87),
                              ),
                              Expanded(
                                child: _buildAssetDetail(
                                    'STOP LOSS',
                                    asset.stopLoss != null
                                        ? 'EGP ${asset.stopLoss!.toStringAsFixed(2)}'
                                        : 'N/A',
                                    color: const Color(0xFFFF3B30)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              if (activePortfolio != null && activePortfolio.assets.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: PremiumEmptyState(
                    icon: Icons.pie_chart_outline_rounded,
                    title: 'Empty Portfolio',
                    subtitle:
                        'Your investment journey is just a click away. Add your first asset to track its performance!',
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            title: const Text('Investments',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            backgroundColor: const Color(0xFFF2F2F7),
            floating: true,
            pinned: true,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
            actions: [
              IconButton(
                icon: const Icon(Icons.account_circle_outlined, color: Colors.black),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
              ),
            ],
          ),
          const SliverToBoxAdapter(
            child: EliteHeader(title: 'Portfolio & Assets'),
          ),
        ],
        body: Stack(
          children: [
            myPortfolioView,
            const ConnectivityIndicator(),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton(
          heroTag: null,
          onPressed: _showAddAssetDialog,
          backgroundColor: Colors.black,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }



  Widget _buildAssetDetail(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
