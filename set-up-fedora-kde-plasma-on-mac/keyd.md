# Remap shortcuts prior to compositor

KDE and macOS have a significant amount of similar shortcuts and these shortcuts differ in the modifier, only. As a result, the most efficient approach to transplant macOS shortcuts to KDE is to swap the `⌘` key and the `control` key when they are held.



##### Install `keyd`

```shell
$ sudo dnf copr enable fmonteghetti/keyd
$ sudo dnf install keyd

$ sudo mkdir /etc/keyd/
$ sudo touch /etc/keyd/default.conf
$ sudo vim /etc/keyd/default.conf
```

Copy and paste:

```shell
[ids]
*

[main]

##########################
# Non-modifier shortcuts #
##########################

# show desktop
f11 = C-f12

# exposé
f3 = C-f9

###############################
# [hold control] -> [hold ⌘] #
###############################
control = layer(hold_meta)

###############################
# [hold ⌘] -> [hold control] #
###############################
meta = layer(hold_control)

###########################
# [hold control] override #
###########################
[hold_meta:M]
left = M-C-left
right = M-C-right

######################
# [hold ⌘] override #
######################
[hold_control:C]

# quit application
q = A-f4

# zoom
minus = C-minus
equal = C-equal

# history navigation
] = A-right
[ = A-left

# text navigation
left = home
right = end

###########################################
# [hold ⌘+shift] -> [hold control+shift] #
###########################################
[hold_control+shift]

# tab navigation
] = C-pagedown
[ = C-pageup

# screenshot
4 = M-S-print

##########################
# [hold option] override #
##########################
[alt]

# word navigation
left = C-left
right = C-right
```



```shell
$ sudo systemctl enable keyd
$ sudo systemctl start keyd
$ systemctl status keyd
```

> [!TIP]
>
> Use `$ sudo systemctl start keyd` to restart