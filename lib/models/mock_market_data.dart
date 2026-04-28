class MockStock {
  final String symbol;
  final String name;
  final double price;
  final double changePercent;
  final String indicatorStatus; // 'positive', 'negative', 'neutral'

  const MockStock({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePercent,
    required this.indicatorStatus,
  });
}

class MockMarketData {
  static const List<MockStock> egyptStocks = [
    MockStock(symbol: 'COMI.CA', name: 'Commercial International Bank', price: 75.50, changePercent: 1.2, indicatorStatus: 'positive'),
    MockStock(symbol: 'HRHO.CA', name: 'EFG Hermes', price: 18.20, changePercent: -0.5, indicatorStatus: 'negative'),
    MockStock(symbol: 'FWRY.CA', name: 'Fawry', price: 5.40, changePercent: 2.1, indicatorStatus: 'positive'),
    MockStock(symbol: 'TMGH.CA', name: 'Talaat Moustafa Group', price: 26.80, changePercent: 0.8, indicatorStatus: 'positive'),
    MockStock(symbol: 'ESRS.CA', name: 'Ezz Steel', price: 65.30, changePercent: -1.5, indicatorStatus: 'negative'),
    MockStock(symbol: 'ORAS.CA', name: 'Orascom Construction', price: 195.00, changePercent: 0.0, indicatorStatus: 'neutral'),
    MockStock(symbol: 'SWDY.CA', name: 'El Sewedy Electric', price: 32.10, changePercent: 3.4, indicatorStatus: 'positive'),
    MockStock(symbol: 'ABUK.CA', name: 'Abu Qir Fertilizers', price: 85.00, changePercent: -0.2, indicatorStatus: 'neutral'),
    MockStock(symbol: 'AMOC.CA', name: 'AMOC', price: 9.75, changePercent: -1.1, indicatorStatus: 'negative'),
    MockStock(symbol: 'CIEB.CA', name: 'Credit Agricole Egypt', price: 22.40, changePercent: 0.5, indicatorStatus: 'positive'),
  ];

  static const List<MockStock> egyptFunds = [
    MockStock(symbol: 'AZ-SAVINGS', name: 'Azimut Savings Fund', price: 12.50, changePercent: 0.1, indicatorStatus: 'positive'),
    MockStock(symbol: 'CI-MACRO', name: 'CI Capital Macro Fund', price: 104.20, changePercent: 0.8, indicatorStatus: 'positive'),
    MockStock(symbol: 'NBE-FUND4', name: 'NBE Mutual Fund 4', price: 215.00, changePercent: 0.3, indicatorStatus: 'neutral'),
  ];

  static const List<MockStock> saudiStocks = [
    MockStock(symbol: '2010.SR', name: 'SABIC', price: 78.90, changePercent: 0.4, indicatorStatus: 'positive'),
    MockStock(symbol: '1120.SR', name: 'Al Rajhi Bank', price: 85.20, changePercent: 1.1, indicatorStatus: 'positive'),
    MockStock(symbol: '2222.SR', name: 'Saudi Aramco', price: 30.15, changePercent: -0.2, indicatorStatus: 'neutral'),
    MockStock(symbol: '1180.SR', name: 'SNB', price: 38.50, changePercent: 0.8, indicatorStatus: 'positive'),
    MockStock(symbol: '7010.SR', name: 'STC', price: 41.30, changePercent: -0.5, indicatorStatus: 'negative'),
    MockStock(symbol: '5110.SR', name: 'Saudi Electricity', price: 19.80, changePercent: 0.0, indicatorStatus: 'neutral'),
    MockStock(symbol: '2280.SR', name: 'Almarai', price: 58.70, changePercent: 1.5, indicatorStatus: 'positive'),
    MockStock(symbol: '1060.SR', name: 'SABB', price: 40.20, changePercent: -1.2, indicatorStatus: 'negative'),
    MockStock(symbol: '2060.SR', name: 'TASNEE', price: 14.30, changePercent: 2.3, indicatorStatus: 'positive'),
    MockStock(symbol: '4280.SR', name: 'Kingdom Holding', price: 7.95, changePercent: -0.1, indicatorStatus: 'neutral'),
  ];

  static const List<MockStock> uaeStocks = [
    MockStock(symbol: 'EMAAR.DU', name: 'Emaar Properties', price: 8.45, changePercent: 1.8, indicatorStatus: 'positive'),
    MockStock(symbol: 'ENBD.DU', name: 'Emirates NBD', price: 17.20, changePercent: -0.4, indicatorStatus: 'neutral'),
    MockStock(symbol: 'DIB.DU', name: 'Dubai Islamic Bank', price: 5.90, changePercent: 0.6, indicatorStatus: 'positive'),
    MockStock(symbol: 'DEWA.DU', name: 'DEWA', price: 2.45, changePercent: 0.0, indicatorStatus: 'neutral'),
    MockStock(symbol: 'FAB.AD', name: 'First Abu Dhabi Bank', price: 13.80, changePercent: 1.2, indicatorStatus: 'positive'),
    MockStock(symbol: 'ADCB.AD', name: 'ADCB', price: 8.95, changePercent: -1.1, indicatorStatus: 'negative'),
    MockStock(symbol: 'ALDA.AD', name: 'Aldar Properties', price: 5.75, changePercent: 2.5, indicatorStatus: 'positive'),
    MockStock(symbol: 'ETISALAT.AD', name: 'e&', price: 19.30, changePercent: 0.3, indicatorStatus: 'positive'),
    MockStock(symbol: 'ADNOCDIST.AD', name: 'ADNOC Distribution', price: 3.60, changePercent: -0.8, indicatorStatus: 'negative'),
    MockStock(symbol: 'AIRARABIA.DU', name: 'Air Arabia', price: 2.85, changePercent: 0.7, indicatorStatus: 'positive'),
  ];
}
