# Define the State Data Structure

The first thing to do is defining a data structure to store your app state.
To do that, we need to find what should be considered as the app state.

We know there are at least two components requires state, the product list
and the cart icon.

In the source code, the product list corresponds to the `ProductList` widget,
and the cart icon corresponds to the `ShoppingCartIcon`.

Let's first look at the `ProductList` widget. This widget builds the
scrollable body and display the google products. Since it needs to know what
product to display and which products are already in the cart, the
`ProductListState` stores the `productList` and the `purchaseList`.

```dart
class ProductListState extends State<ProductList> {
  List<String> get productList => _productList;
  List<String> _productList = Server.getProductList();
  set productList (List<String> value) {
    setState(() {
      _productList = value;
    });
  }

  Set<String> get purchaseList => _purchaseList;
  Set<String> _purchaseList = <String>{};
  set purchaseList(Set<String> value) {
    setState(() {
      _purchaseList = value;
    });
  }

  // ...
}
```

On the other hand, the `ShoppingCartIcon` also stores `purchaseList` because
it needs to know number of products that are in the cart.

```dart
class ShoppingCartIconState extends State<ShoppingCartIcon> {
  Set<String> get purchaseList => _purchaseList;
  Set<String> _purchaseList = <String>{};
  set purchaseList(Set<String> value) {
    setState(() {
      _purchaseList = value;
    });
  }

  //...
}


```

This is where things get interesting. Both `ShoppingCartIcon` and `ProductList` store their own
version of `purchaseList`, and they need to be kept in sync. When the `purchaseList` is updated
in `ProductList` widget, it also needs to update the state in `ShoppingCartIcon` widget. It can
become very messy quickly if there are more more widgets depends on the `purchaseList`.

Now let's pull these states out of the widgets. The first thing we want to do is to define a
data structure to store the states.

Please refers to the IDE.

```dart
class StateData {
  // Please fill in this data structure.
}
```