# Introduction

State management has been a really important topic in mobile development.
We provide various tool to make the process of building the state
management system easier for our developers. In this workshop, you will
learn how to handle your app state by using the InheritedWidget.




# An Overview

The workshop will include a series of steps to convert an app without
any state management to a fully centralized state management system.

You are started with a demo Google store app. To see how the app looks
like, click the `Run` button on the top right corner of the IDE.

In this app, you can scroll through different google products and
add/remove products from the cart. The small cart icon on the right of
the app bar changes based on number of the products in the cart. You can
also perform search queries by clicking the search icon in the app bar
and type `"nest"` to filter nest products.

Based on the functionality of this app, there are two components that
require states.

1. The cart icon needs to store how many items is in the cart.
2. The product list widget needs to store which item is already in cart, and
what the search query is.

This app is writing poorly without any state management. Let's see how
we can improve this app!
