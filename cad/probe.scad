include <lib/sbc-helpers.scad>
probe = "";
if (probe == "full") sbc(model="rpi5", enablemask=true);
if (probe == "sides") sbc(model="rpi5", enableheatsink="disable", enablegpio="disable", enablemask=true);
