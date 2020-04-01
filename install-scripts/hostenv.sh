#!/usr/bin/python


for each in (open("/proc/1/environ").read().split('\x00')):
    if len(each.split("=")) == 2:
        var = each.split("=")[0]
        val = each.split("=")[1]
        val = val.replace("@"," ")
        if var == "HOME":
           continue
        print("export %s='%s'" % (var,val))
    else:
        print (each)
