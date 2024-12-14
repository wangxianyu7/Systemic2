#!/bin/bash
LD_LIBRARY_PATH="`pwd`:$LD_LIBRARY_PATH" java -Xmx1g -Dswing.defaultlaf=com.sun.java.swing.plaf.nimbus.NimbusLookAndFeel -jar SystemicGui.jar