/// Refreshes in-memory catalog/party lists on transaction screens still mounted in [AppShell].
/// Handlers should reload remote API data (products, units, customers, suppliers, etc.).
final _productCatalogRefreshHandlers = <Future<void> Function()>{};

void registerProductCatalogRefresh(Future<void> Function() handler) {
  _productCatalogRefreshHandlers.add(handler);
}

void unregisterProductCatalogRefresh(Future<void> Function() handler) {
  _productCatalogRefreshHandlers.remove(handler);
}

Future<void> refreshMountedProductCatalogs() async {
  for (final handler in _productCatalogRefreshHandlers) {
    await handler();
  }
}
