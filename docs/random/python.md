---
sidebar_position: 2
title: Python
description: "Python Deep Dive."
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

Python has four data structures: set, list, dict, tuple

## Set
A set is a collection which is: 
- Unordered: items can appear in a different order every time, cannot be referred to by index or key.
- Unchangeable: but you can remove items and add new items.
- Unindexed.
- Unique.

```python
bucket = {"apple", "banana", "cherry"}
len(bucket)

"banana" in thisset

"banana" not in thisset

bucket.add("orange")

thisset = {"apple", "banana", "cherry"}
tropical = {"pineapple", "mango", "papaya"}
thisset.update(tropical)

bucket.remove("banana") 
# If the item to remove does not exist, remove() will raise an error.

bucket.discard("banana")

# pop() method to remove a random item

bucket.clear()
```

```python
myset = set1 | set2 | set3 |set4 # Union

set3 = set1 & set2 # Intersection

set3 = set1 - set2 # Difference

set3 = set1 ^ set2 # Symmetric Difference
```

Methods see [here](https://www.w3schools.com/python/python_sets_methods.asp)



