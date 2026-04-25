> [!WARNING]
> This is very experimental; there is a chance you might brick your system.
## Installation
When installed through RetroPie-Setup, this package installs its launcher to both `/usr/bin/emulationstation` and RetroPie's default frontend path at `/opt/retropie/supplementary/emulationstation/emulationstation`. That makes Batocera EmulationStation replace the stock frontend automatically after install, without a manual binary swap.
```
  cd RetroPie-Setup/scriptmodules/supplementary
```
```
  wget https://raw.githubusercontent.com/Cyborg-Taco/Batocera-ES-for-Retropie/refs/heads/master/Batocera-ES-for-Retropie.sh
```
```
  cd
  cd RetroPie-Setup
  sudo ./retropie_setup.sh
```
Then go to:
`Manage Packages > Experimental > Batocera-ES-for-Retropie > Update Batocera-ES-for-Retropie`
