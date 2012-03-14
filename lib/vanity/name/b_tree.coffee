# Implements a B-Tree for quickly finding a name based on its cumulative frequency.
#
# Exports a function that returns a tree.  The tree supports two methods:
# - add(key, value) adds a value at the specified key (key is number, value is string)
# - done() balances the tree and returns the finder function
#
# The finder function accepts a key and returns a value.
#
# For example:
#
#   BTree = require("b_tree")
#   my_tree = BTree()
#   my_tree.add 5, "5 percent"
#   my_tree.add 75, "75 percent"
#   find = my_tree.done()
#   console.log find(50)
#   => "75 percent"
#
# ---
#
# We want to return a name based on its actual distribution in the US population.  For example, Mary is the most popular
# name at 2.629%, but Beverly is only at 0.2627%.  We want to return Mary 10x more often than we return Beverly.
#
# To do that, we pick an evenly distributed number between 0 and 100 (exclusive), and we use that to pick a name based
# on its cumulative frequency.
#
# The cumulative frequency of Beverly is 36.9, so any value above that would pick some other name.  The cumulative
# frequency of Theresa is 36.633, so only a value between 36.633 (exclusive) and 36.9 (inclusive) will match Beverly.
# That gap is exactly 0.267.
#
# So given a list of names and their cumulative frequency (which the US Census Bureau so nicely provides us), and some
# value between 0 and 100, all we need is a quick way to find the name with cumulative frequency range that includes
# that value.  B-Tree does that.
#
# ---
#
# Fortunately for us, the list we're working from is sorted by cumulative frequency, and since building a full B-Tree
# implementation is boring, we're going to build an algorithm that can only do two things:
# - Iterate through the sorted set and construct a binary tree without having to balance nodes
# - A finder
#
# The final binary tree looks like this: eacn node is an object with properties left, right and limit.  If a key is
# at/below limit, pick the left, otherwise pick the right.  Each node has a string (name) for left/right values.
#
#                         Left                            Limit
#          Left           Limit         Right             12.361
#    Left  Limit  Right   6.589   Left  Limit  Right      
#   James  3.318  John           Robert 9.732 Michael      ...
#
# To construct the tree, we process entries in order (from low to high), and work one layer at a time.  The layers
# themselves are discarded later on.
#
# A layer consists of one or more nodes, reference to the current node (current), layer above (up) and highest layer
# (top).
#
# First time we add an item, we create a new node (referenced by current) and set it's left value.  Second time we add
# an item, we use that same node and set it's limit and right value.  We then repeat this odd/even pattern and create
# half as many nodes as we have items.
#
# However, the third time we add an item, we have two nodes and so we need to introduce a node one layer up.  We do that
# every time we have two nodes.  To keep the algorithm simple, we just call add_item on the up layer for each new node,
# starting with the second one.


# Add item to a given layer of the b-tree.
#
# layer - The B-Tree layer (an Object)
# limit - The limit; any key at/below this selects the value
# value - The value to select (name or node)
add_item = (layer, limit, value)->
  if current = layer.current
    # Currently adding this node, so it has left but no limit or right.
    current.right = value
    current.max = limit
    layer.current = null
  else
    # No nodes or starting from a new node
    current = { left: value, limit: limit }
    layer.current = current

    # Every time we create a new node, except for the first one, we need to add it one layer up.
    # But we do need to add the first node once.
    if first = layer.first
      unless layer.up
        layer.up = {}
        add_item layer.up, first.max, first
      add_item layer.up, limit, current
    else
      # This is the first (possibly only) node at this layer
      layer.first = current
  return


# Find the top most node in the tree, starting from the bottom layer.
find_top = (layer)->
  # Each layer that has two/more nodes points upwards, otherwise layer has one node, and we just need to return that
  # node.
  return if layer.up then find_top(layer.up) else layer.first


# Balance the node (and all its children).  During construction we don't calculate the proper limit (or max) of a
# node, so we need this bit of post-processing.
balance = (node)->
  return if typeof node.left == "string"
  balance node.left
  node.limit = node.left.max || node.left.limit
  if node.right
    balance node.right
    node.max = node.right.max if node.right.max


# Recrusively find value based on key. 
find = (node, key)->
  next = if node.right && key > node.limit then node.right else node.left
  return if typeof next == "string" then next else find(next, key)


# This is the tree constructor function.  It returns an object with two methods: add and done.
tree = ->
  # This is the bottom layer.  Every tree (even empty one) has bottom layer of leaves.
  bottom = {}
  object =
    add: (key, value)->
      add_item bottom, key, value
    done: ->
      top = find_top(bottom)
      balance top
      return find.bind(this, top)
  return object


module.exports = tree
