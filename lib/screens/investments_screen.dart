import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import '../services/market_data_service.dart';
import '../widgets/connectivity_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'profile_screen.dart';
import 'calendar_screen.dart';

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

  String _marketSearchQuery = '';
  String _marketFilter = 'Stocks';
  final Map<String, TextEditingController> _qtyControllers = {};

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

  Future<void> _createDefaultPortfolioIfMissing() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('investments');

    try {
      // 2. Start reactive stream (Stream) for live updates
      _portfoliosSub = collection.snapshots().listen(
        (QuerySnapshot<Map<String, dynamic>> snapshot) {
          final loadedPortfolios = snapshot.docs
              .map((doc) => Portfolio.fromJson(doc.data()))
              .toList();

          if (mounted) {
            setState(() {
              _portfolios = loadedPortfolios;
              if (loadedPortfolios.isNotEmpty) {
                if (_activePortfolioId == null ||
                    !loadedPortfolios.any((p) => p.id == _activePortfolioId)) {
                  _activePortfolioId = loadedPortfolios.first.id;
                }
              }
            });
          }
        },
        onError: (e) {
          debugPrint('Firestore Error loading portfolios: $e');
          if (mounted) setState(() => _isLoading = false);
        },
      )..onError((error) {
          if (mounted) setState(() => _isLoading = false);
        });
    } catch (e) {
      debugPrint('Error initializing portfolios: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addPortfolio(String name) async {
    if (name.trim().isEmpty) return;
    final newPortfolio = Portfolio(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('investments')
          .doc(newPortfolio.id)
          .set(newPortfolio.toJson());

      // Update local asset cache for alerts
      if (mounted) {
        context.read<MarketDataService>().fetchUserAssets();
      }

      if (mounted) {
        setState(() => _activePortfolioId = newPortfolio.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Portfolio "${newPortfolio.name}" created')),
        );
      }
    } catch (e) {
      debugPrint('Error adding portfolio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create portfolio: $e')),
        );
      }
    }
  }

  void _deletePortfolio(Portfolio portfolio) {
    if (_portfolios.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the last profile.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: Text(
            'Are you sure you want to delete "${portfolio.name}" and all its assets?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('investments')
                    .doc(portfolio.id)
                    .delete();

                // Update local asset cache for alerts
                if (context.mounted) {
                  context.read<MarketDataService>().fetchUserAssets();
                }
              }
              if (!context.mounted) return;
              Navigator.pop(context);
              if (mounted) {
                setState(() {
                  if (_activePortfolioId == portfolio.id) {
                    _activePortfolioId =
                        _portfolios.firstWhere((p) => p.id != portfolio.id).id;
                  }
                });
              }
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

    String? token;
    try {
      token = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Error getting token for asset: $e');
    }

    final totalCost = buyPrice * quantity;
    if (totalCost > activePortfolio.balance) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient balance to add this asset')),
        );
      }
      return;
    }

    activePortfolio.balance -= totalCost;

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

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('investments')
            .doc(activePortfolio.id)
            .set(activePortfolio.toJson());

        // Update local asset cache for alerts
        if (mounted) {
          context.read<MarketDataService>().fetchUserAssets();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Asset "${newAsset.name}" added')),
          );
        }
      } catch (e) {
        debugPrint('Error adding asset: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add asset: $e')),
          );
        }
      }
    }
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

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('investments')
            .doc(activePortfolio.id)
            .set(activePortfolio.toJson());

        // Update local asset cache for alerts
        if (mounted) {
          context.read<MarketDataService>().fetchUserAssets();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Asset "${name.trim()}" updated')),
          );
        }
      } catch (e) {
        debugPrint('Error updating asset: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update asset: $e')),
          );
        }
      }
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Asset'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: asset.name),
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return const Iterable<String>.empty();
                    }
                    return marketData.keys.where((String option) {
                      return option
                          .contains(textEditingValue.text.toUpperCase());
                    });
                  },
                  onSelected: (String selection) {
                    nameController.text = selection;
                    final price = marketData[selection]?['price'];
                    if (price != null) {
                      currentPriceController.text = price.toString();
                    }
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                    controller.addListener(() {
                      nameController.text = controller.text;
                    });
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      onFieldSubmitted: (value) => onFieldSubmitted(),
                      decoration: const InputDecoration(
                        labelText: 'Asset Name (e.g., COMI.CA)',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Required'
                              : null,
                      textCapitalization: TextCapitalization.characters,
                    );
                  },
                ),
                TextFormField(
                  controller: buyPriceController,
                  decoration: const InputDecoration(labelText: 'Buy Price'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (double.tryParse(value) == null) return 'Invalid number';
                    return null;
                  },
                ),
                TextFormField(
                  controller: currentPriceController,
                  decoration: const InputDecoration(labelText: 'Current Price'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (double.tryParse(value) == null) return 'Invalid number';
                    return null;
                  },
                ),
                TextFormField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (double.tryParse(value) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: takeProfitController,
                  decoration: const InputDecoration(
                      labelText: 'Target Price (Take Profit)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        double.tryParse(value) == null) {
                      return 'Invalid number';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: stopLossController,
                  decoration:
                      const InputDecoration(labelText: 'Stop Loss Price'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        double.tryParse(value) == null) {
                      return 'Invalid number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _updateAsset(
                  asset,
                  nameController.text,
                  double.parse(buyPriceController.text),
                  double.parse(currentPriceController.text),
                  double.parse(quantityController.text),
                  takeProfitController.text.isNotEmpty
                      ? double.parse(takeProfitController.text)
                      : null,
                  stopLossController.text.isNotEmpty
                      ? double.parse(stopLossController.text)
                      : null,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
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

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('investments')
          .doc(activePortfolio.id)
          .set(activePortfolio.toJson());

      // Update local asset cache for alerts
      if (!mounted) return;
      context.read<MarketDataService>().fetchUserAssets();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough shares to sell')),
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('investments')
          .doc(portfolio.id)
          .set(portfolio.toJson());

      if (mounted) {
        context.read<MarketDataService>().fetchUserAssets();
      }
    } catch (e) {
      debugPrint('Error syncing portfolio: $e');
    }
  }

  void _showUpdateBudgetDialog(Portfolio portfolio) {
    final controller =
        TextEditingController(text: portfolio.initialBudget.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Initial Budget'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Budget (EGP)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
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
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
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

  void _showAddPortfolioDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Profile'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Profile Name'),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _addPortfolio(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showAddAssetDialog() {
    final nameController = TextEditingController();
    final buyPriceController = TextEditingController();
    final currentPriceController = TextEditingController();
    final quantityController = TextEditingController();
    final takeProfitController = TextEditingController();
    final stopLossController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final marketData = context.read<MarketDataService>().stocksData;

    nameController.addListener(() {
      final ticker = nameController.text.trim().toUpperCase();
      // Only auto-fill if we have exactly matched a ticker or if the user stopped typing
      if (marketData.containsKey(ticker)) {
        final price = marketData[ticker]['price'];
        if (price != null) {
          final priceStr = price.toString();
          if (currentPriceController.text != priceStr) {
            currentPriceController.text = priceStr;
          }
        }
      }
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Asset'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return const Iterable<String>.empty();
                    }
                    return marketData.keys.where((String option) {
                      return option
                          .contains(textEditingValue.text.toUpperCase());
                    });
                  },
                  onSelected: (String selection) {
                    nameController.text = selection;
                    // Trigger price update immediately on selection
                    final price = marketData[selection]?['price'];
                    if (price != null) {
                      currentPriceController.text = price.toString();
                    }
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                    // Sync the autocomplete's internal controller with our nameController
                    controller.addListener(() {
                      nameController.text = controller.text;
                    });
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      onFieldSubmitted: (value) => onFieldSubmitted(),
                      decoration: const InputDecoration(
                        labelText: 'Asset Name (e.g., COMI.CA)',
                        hintText: 'Start typing to search...',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Required'
                              : null,
                      textCapitalization: TextCapitalization.characters,
                    );
                  },
                ),
                TextFormField(
                  controller: buyPriceController,
                  decoration: const InputDecoration(labelText: 'Buy Price'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (double.tryParse(value) == null) return 'Invalid number';
                    return null;
                  },
                ),
                TextFormField(
                  controller: currentPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Current Price',
                    hintText: 'Auto-fills if ticker is recognized',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (double.tryParse(value) == null) return 'Invalid number';
                    return null;
                  },
                ),
                TextFormField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (double.tryParse(value) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: takeProfitController,
                  decoration: const InputDecoration(
                      labelText: 'Target Price (Take Profit)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        double.tryParse(value) == null) {
                      return 'Invalid number';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: stopLossController,
                  decoration:
                      const InputDecoration(labelText: 'Stop Loss Price'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        double.tryParse(value) == null) {
                      return 'Invalid number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _addAsset(
                  nameController.text,
                  double.parse(buyPriceController.text),
                  double.parse(currentPriceController.text),
                  double.parse(quantityController.text),
                  takeProfitController.text.isNotEmpty
                      ? double.parse(takeProfitController.text)
                      : null,
                  stopLossController.text.isNotEmpty
                      ? double.parse(stopLossController.text)
                      : null,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Portfolio Locked',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please sign in to manage your personal portfolios.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  // Standard practice to navigate back to login in this app's architecture
                  // is to ensure the auth state is null, which triggers the root AuthWrapper.
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
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
              padding: const EdgeInsets.only(left: 8.0),
              child: ActionChip(
                label:
                    const Text('+ New', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.transparent,
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                onPressed: _showAddPortfolioDialog,
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
                // Redesigned Broker Dashboard Summary Card
                Card(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                  color: const Color(0xFF1A1A1A),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => _showUpdateBudgetDialog(activePortfolio),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BUYING POWER (CASH)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      color: Colors.blueAccent.withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'EGP ${activePortfolio.balance.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
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
                                            ? Colors.greenAccent
                                            : Colors.redAccent)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${totalPnlPercent >= 0 ? '+' : ''}${totalPnlPercent.toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: totalPnlEgp >= 0
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'EGP ${totalPnlEgp >= 0 ? '+' : ''}${totalPnlEgp.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: totalPnlEgp >= 0
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
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
                        Text(
                          'EGP ${portfolioValue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 100,
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(FirebaseAuth.instance.currentUser?.uid)
                                .collection('investments')
                                .doc(activePortfolio.id)
                                .collection('portfolio_snapshots')
                                .orderBy('timestamp', descending: true)
                                .limit(14) // Fetch last 2 weeks for trend
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white24),
                                );
                              }

                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No performance data yet.',
                                    style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                );
                              }

                              // Reverse snapshots to get chronological order [Oldest -> Newest]
                              final docs = snapshot.data!.docs.reversed.toList();
                              final List<FlSpot> spots = [];
                              
                              for (int i = 0; i < docs.length; i++) {
                                final data = docs[i].data() as Map<String, dynamic>;
                                final val = data['total_value'];
                                if (val is num) {
                                  spots.add(FlSpot(i.toDouble(), val.toDouble()));
                                }
                              }

                              if (spots.length < 2) {
                                return Center(
                                  child: Text(
                                    'Not enough data for chart.',
                                    style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                );
                              }

                              final lineColor = totalPnlEgp >= 0
                                  ? Colors.greenAccent
                                  : Colors.redAccent;

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
                                            lineColor.withValues(alpha: 0.2),
                                            lineColor.withValues(alpha: 0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  lineTouchData: LineTouchData(
                                    touchTooltipData: LineTouchTooltipData(
                                      getTooltipColor: (_) => Colors.black.withValues(alpha: 0.8),
                                      getTooltipItems: (touchedSpots) {
                                        return touchedSpots.map((spot) {
                                          return LineTooltipItem(
                                            'EGP ${spot.y.toStringAsFixed(2)}',
                                            const TextStyle(
                                              color: Colors.white,
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
                ),
              ] else ...[
                const SizedBox(height: 64),
                const Center(
                  child: Text(
                    'No profiles found.',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
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
                  final assetProfitEgp = (livePrice - asset.buyPrice) * asset.quantity;

                  return Dismissible(
                    key: Key(asset.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child:
                          const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    onDismissed: (_) => _deleteAsset(asset),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: const Color(0xFF0F0F0F),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        knownFunds[asset.name] ??
                                            knownStocks[asset.name] ??
                                            asset.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
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
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          _showSellActionDialog(asset, livePrice),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        minimumSize: Size.zero,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('SELL',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 20, color: Colors.blueAccent),
                                      onPressed: () =>
                                          _showEditAssetDialog(asset),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Divider(color: Colors.white10, height: 1),
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
                                          ? Colors.greenAccent
                                          : Colors.redAccent),
                                ),
                                Expanded(
                                  child: _buildAssetDetail(
                                      'ROI',
                                      'EGP ${assetProfitEgp >= 0 ? '+' : ''}${assetProfitEgp.toStringAsFixed(1)} (${assetRoi >= 0 ? '+' : ''}${assetRoi.toStringAsFixed(1)}%)',
                                      color: assetRoi >= 0
                                          ? Colors.greenAccent
                                          : Colors.redAccent),
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
                                      color: Colors.greenAccent
                                          .withValues(alpha: 0.7)),
                                ),
                                Expanded(
                                  child: _buildAssetDetail('TOTAL',
                                      'EGP ${(asset.buyPrice * asset.quantity).toStringAsFixed(2)}',
                                      color: Colors.white70),
                                ),
                                Expanded(
                                  child: _buildAssetDetail(
                                      'STOP LOSS',
                                      asset.stopLoss != null
                                          ? 'EGP ${asset.stopLoss!.toStringAsFixed(2)}'
                                          : 'N/A',
                                      color: Colors.redAccent
                                          .withValues(alpha: 0.7)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              if (activePortfolio != null && activePortfolio.assets.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Center(
                    child: Text(
                      'No assets added yet.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );

    final marketStatusView = Consumer<MarketDataService>(
      builder: (context, service, _) {
        // If the service is loading for the first time
        if (service.isLoading && !service.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // If there's an error and no cached data, show error
        if (service.error != null && !service.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, color: Colors.grey.shade500, size: 48),
                const SizedBox(height: 16),
                Text('Could not load market data',
                    style: TextStyle(color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => service.fetchAllMarketData(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // If no data at all
        if (!service.hasData) {
          return Center(
              child: Text('No market data available',
                  style: TextStyle(color: Colors.grey.shade500)));
        }

        final stocksData = service.stocksData;
        var stockEntries = stocksData.entries.toList();

        stockEntries = stockEntries.where((entry) {
          final ticker = entry.key;
          final isFund = knownFunds.containsKey(ticker);
          if (_marketFilter == 'Funds' && !isFund) return false;
          if (_marketFilter == 'Stocks' && isFund) return false;
          return true;
        }).toList();

        if (_marketSearchQuery.isNotEmpty) {
          final query = _marketSearchQuery.toLowerCase();
          stockEntries = stockEntries.where((entry) {
            final ticker = entry.key.toLowerCase();
            final fullName =
                (knownFunds[entry.key] ?? knownStocks[entry.key] ?? entry.key)
                    .toLowerCase();
            return ticker.contains(query) || fullName.contains(query);
          }).toList();
        }

        stockEntries.sort((a, b) => a.key.compareTo(b.key));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search ticker or name...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _marketSearchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Stocks'),
                        selected: _marketFilter == 'Stocks',
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _marketFilter = 'Stocks';
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Funds'),
                        selected: _marketFilter == 'Funds',
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _marketFilter = 'Funds';
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => service.fetchAllMarketData(),
                color: Colors.white,
                backgroundColor: const Color(0xFF1E1E1E),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: stockEntries.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ticker = stockEntries[index].key;
                    final data =
                        stockEntries[index].value as Map<String, dynamic>;
                    final fullName =
                        knownFunds[ticker] ?? knownStocks[ticker] ?? ticker;

                    final priceRaw = data['price'];
                    final rsiRaw = data['rsi'];
                    final macdRaw = data['macd'] as String? ?? 'N/A';
                    final price = priceRaw is num ? priceRaw.toDouble() : 0.0;
                    final rsi = rsiRaw is num ? rsiRaw.toDouble() : 0.0;
                    final isDataAvailable = priceRaw is num;

                    // Sentiment Logic
                    Color sentimentColor;
                    String sentimentLabel;
                    if (!isDataAvailable) {
                      sentimentColor = Colors.grey.shade600;
                      sentimentLabel = 'OFFLINE';
                    } else if (rsi <= 35) {
                      sentimentColor = Colors.greenAccent;
                      sentimentLabel = 'OVERSOLD';
                    } else if (rsi >= 70) {
                      sentimentColor = Colors.redAccent;
                      sentimentLabel = 'OVERBOUGHT';
                    } else {
                      sentimentColor = Colors.blueAccent;
                      sentimentLabel = 'NEUTRAL';
                    }

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: sentimentColor.withValues(alpha: 0.05),
                            blurRadius: 20,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            // Glass Background
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            // Sentiment Ribbon (Vertical)
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 4,
                              child: Container(color: sentimentColor),
                            ),
                            // Content
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title & Ticker
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fullName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              ticker,
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Metrics Grid
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildMetricPill(
                                            label: 'PRICE',
                                            value: isDataAvailable
                                                ? '\$${price.toStringAsFixed(2)}'
                                                : 'N/A',
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          _buildMetricPill(
                                            label: 'RSI',
                                            value: isDataAvailable
                                                ? rsi.toStringAsFixed(0)
                                                : 'N/A',
                                            color: sentimentColor,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Tags Section (Scrollable horizontally)
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: sentimentColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            sentimentLabel,
                                            style: TextStyle(
                                              color: sentimentColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                            maxLines: 1,
                                            softWrap: false,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.05),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.analytics_outlined,
                                                size: 12,
                                                color: Colors.grey.shade400,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                macdRaw.toUpperCase(),
                                                style: TextStyle(
                                                  color: Colors.grey.shade300,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.5,
                                                ),
                                                maxLines: 1,
                                                softWrap: false,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );

    return Theme(
      data: Theme.of(context).copyWith(
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Investments',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined,
                  color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CalendarScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.account_circle_outlined,
                  color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProfileScreen()),
                );
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFFFFFFF),
            labelColor: const Color(0xFFFFFFFF),
            unselectedLabelColor: const Color(0xFF888888),
            tabs: const [
              Tab(text: 'My Wallet'),
              Tab(text: 'Market Status'),
            ],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                myPortfolioView,
                marketStatusView,
              ],
            ),
            const ConnectivityIndicator(),
          ],
        ),
        floatingActionButton:
            (_tabController.index == 0 && _activePortfolioId != null)
                ? FloatingActionButton(
                    heroTag: null,
                    onPressed: _showAddAssetDialog,
                    child: const Icon(Icons.add),
                  )
                : null,
      ),
    );
  }

  Widget _buildMetricPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
              color: color ?? Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
