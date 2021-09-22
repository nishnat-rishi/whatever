# Organizer

From draw calls and input event callbacks to a fully working Organizer. Everything implemented from scratch.

---

![demo](https://github.com/nishnat-rishi/whatever/blob/master/whatever-demo.gif?raw=true)

---

## Behind the Scenes

This section is a work in progress. It will break down various elements of the project.

### Painless Transitions

Transitions have always been a pain for me to implement correctly in established UI frameworks. I wanted to simply declare the final position of a UI element, and expect it to comply. Well, with an overhauled custom animation system, I was able to achieve this declarative Nirvana.

Suppose our program contains a button and a list.

```lua
program = {
  buttons = {
    add = {
      pos = {x, y}, -- x, y are values.
      dim = {x, y}
    }
  },
  lists = {
    number_list = list:create{
      pos = {x, y},
      dim = {x, y},
      -- other details
    }
  }
}
```

We want to have 2 pages. One in which only the button is visible (home page), and another page where only the list is visible (data page).

```lua
pages = {
  home = {
    ...
  },
  data = {
    ...
  }
}

```

Here, each element of the `pages` table will reflect the structure of the program as a whole.

```lua
pages = {
  home = {
    buttons = {
      add = {
        ...
      }
    },
    lists = {
      numbers_list = {
        ...
      }
    }
  },
  data = {
    -- same as above
  }
}
```

And in each page, for each element, we will simply declare the final position of those elements.


```lua
pages = {
  home = {
    buttons = {
      add = {
        pos = {
          x = 100
        }
      }
    },
    lists = {
      numbers_list = {
        pos = {
          x = window.x + 100
        }
      }
    }
  },
  data = {
    buttons = {
      add = {
        pos = {
          x = window.x + 100
        }
      }
    },
    lists = {
      numbers_list = {
        pos = {
          x = 100
        }
      }
    }
  }
}
```

We can leave out any key whose value we don't wish to change. (In our case, we leave out `y` since we simply wish to change the `x` value of our elements).

After creating this tree, we can simply use our animation module to perform transitions.

```lua
anim:move{
  program,
  to = pages.home
}
```
or
```lua
anim:move{
  program,
  to = pages.data
}
```

It's really that simple. 