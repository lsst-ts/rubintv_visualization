import 'package:flutter/widgets.dart';

/// An element in a [QuadtTree] and it's location.
class QuadTreeElement<T> {
  /// The item in the [QuadTree].
  final T element;

  /// The location of the item in the [QuadTree].
  final Offset center;

  QuadTreeElement(this.element, this.center);
}

/// A 2D space partitioning data structure.
class QuadTree<T> extends Rect {
  /// Maximum depth of the tree.
  final int maxDepth;

  /// Maximum number of elements in a leaf node.
  final int capacity;

  /// The depth of this node in the tree.
  final int depth;

  /// The elements in this node.
  final List<QuadTreeElement<T>> contents;

  /// The child nodes of this node.
  final List<QuadTree<T>> children;

  /// The index of the top left child node in the list of [children].
  static const topLeftIndex = 0;

  /// The index of the top right child node in the list of [children].
  static const topRightIndex = 1;

  /// The index of the bottom left child node in the list of [children].
  static const bottomLeftIndex = 2;

  /// The index of the bottom right child node in the list of [children].
  static const bottomRightIndex = 3;

  QuadTree({
    required this.maxDepth,
    required this.capacity,
    required this.depth,
    required this.contents,
    required this.children,
    required double left,
    required double top,
    required double width,
    required double height,
  }) : super.fromLTWH(left, top, width, height);

  /// Split this node into four children.
  void _split() {
    double halfWidth = width / 2;
    double halfHeight = height / 2;

    // Top left
    children.add(QuadTree(
      maxDepth: maxDepth,
      capacity: capacity,
      depth: depth + 1,
      contents: [],
      children: [],
      left: left,
      top: top,
      width: halfWidth,
      height: halfHeight,
    ));

    // Top right
    children.add(QuadTree(
      maxDepth: maxDepth,
      capacity: capacity,
      depth: depth + 1,
      contents: [],
      children: [],
      left: center.dx,
      top: top,
      width: halfWidth,
      height: halfHeight,
    ));

    // Bottom left
    children.add(QuadTree(
      maxDepth: maxDepth,
      capacity: capacity,
      depth: depth + 1,
      contents: [],
      children: [],
      left: left,
      top: center.dy,
      width: halfWidth,
      height: halfHeight,
    ));

    children.add(QuadTree(
      maxDepth: maxDepth,
      capacity: capacity,
      depth: depth + 1,
      contents: [],
      children: [],
      left: center.dx,
      top: center.dy,
      width: halfWidth,
      height: halfHeight,
    ));

    for (QuadTreeElement<T> element in contents) {
      _insert(element.element, element.center);
    }
  }

  /// Insert an item into the appropriate child node.
  bool _insert(T item, Offset location) {
    if (location.dx <= center.dx) {
      if (location.dy <= center.dy) {
        return children[topLeftIndex].insert(item, location);
      } else {
        return children[bottomLeftIndex].insert(item, location);
      }
    } else {
      if (location.dy <= center.dy) {
        return children[topRightIndex].insert(item, location);
      } else {
        return children[bottomRightIndex].insert(item, location);
      }
    }
  }

  /// Insert a new [item] into the [QuadTree].
  bool insert(T item, Offset location) {
    if (!contains(location)) {
      return false;
    }

    if (children.isEmpty) {
      if (contents.length < capacity || depth >= maxDepth) {
        // Add the item to the contents of this node.
        contents.add(QuadTreeElement(item, location));
        return true;
      }
      // Split this
      _split();
    }
    return _insert(item, location);
  }

  /// Search for all items in the [QuadTree] that overlap with [rect].
  List<T> queryRect(Rect rect) {
    List<T> result = [];
    if (!overlaps(rect)) {
      return result;
    }

    if (contents.isNotEmpty) {
      for (QuadTreeElement<T> element in contents) {
        if (rect.contains(element.center)) {
          result.add(element.element);
        }
      }
    } else {
      for (QuadTree<T> child in children) {
        result.addAll(child.queryRect(rect));
      }
    }

    return result;
  }

  /// Return the point on the nearest edge to the given [location].
  Offset _nearestEdgeLocation(Offset location) {
    if (location.dx < left) {
      if (location.dy < top) {
        return Offset(left, top);
      } else if (location.dy > bottom) {
        return Offset(left, bottom);
      } else {
        return Offset(left, location.dy);
      }
    } else if (location.dx > right) {
      if (location.dy < top) {
        return Offset(right, top);
      } else if (location.dy > bottom) {
        return Offset(right, bottom);
      } else {
        return Offset(right, location.dy);
      }
    } else {
      if (location.dy < top) {
        return Offset(location.dx, top);
      } else if (location.dy > bottom) {
        return Offset(location.dx, bottom);
      } else {
        return Offset(location.dx, location.dy);
      }
    }
  }

  /// Search for the nearest neighbor to [location].
  QuadTreeElement<T>? _nearestNeighbor(Offset location, {QuadTreeElement<T>? result}) {
    // If the current node contains elements, find the closest one.
    if (contents.isNotEmpty) {
      for (QuadTreeElement<T> element in contents) {
        if (result == null ||
            (element.center - location).distanceSquared < (result.center - location).distanceSquared) {
          result = element;
        }
      }
      return result;
    }

    if (children.isNotEmpty) {
      // First traverse the children that contain the location and find the nearest neighbor.
      int childIndex = -1;
      for (int i = 0; i < 4; i++) {
        QuadTree<T> child = children[i];
        if (child.contains(location)) {
          result = child._nearestNeighbor(location, result: result);
          childIndex = i;
          break;
        }
      }

      // Search all of the other children the are closer than the current nearest neighbor.
      for (int i = 0; i <= 4; i++) {
        if (i != childIndex) {
          QuadTree<T> child = children[i];
          Offset intersection = child._nearestEdgeLocation(location);
          if ((intersection - location).distanceSquared < (result!.center - location).distanceSquared) {
            result = child._nearestNeighbor(location, result: result);
          }
        }
      }
    }

    return result;
  }

  /// Return the item in the tree that is the closest to [location].
  QuadTreeElement<T>? queryPoint(Offset location) => _nearestNeighbor(location);
}
