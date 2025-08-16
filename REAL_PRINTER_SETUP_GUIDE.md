# Real Printer Setup Guide for Restaurant POS System

## ⚠️ **MAJOR UPDATE - NEW ENHANCED FUNCTIONALITY**

Your POS system now includes **REVOLUTIONARY CLICKABLE PRINTER CONFIGURATION**:
- 🖱️ **All printers are now clickable** in the assignment screen
- 🔧 **3-tab configuration interface** (Manual Setup, Network Scan, Bluetooth)
- 📡 **Automatic network discovery** for Epson thermal printers
- ✅ **Real-time connection testing** and test printing functionality
- 🖨️ **Enhanced 80mm thermal printing** with ESC/POS commands

👆 **📋 See `ENHANCED_PRINTER_CONFIGURATION_GUIDE.md` for complete new features!**

---

## Overview (Legacy Information)
This guide covers the basic printer assignment functionality. For the new enhanced features, see the Enhanced Guide above.

## Current Printer Stations Configuration

Your POS system is now configured with these restaurant-specific printer stations:

### 🖨️ **Available Printer Stations**

1. **Main Kitchen Printer** 📍 `192.168.1.100:9100`
   - **Purpose**: Central coordination, order summaries, receipts
   - **Recommended for**: Main kitchen coordination, customer receipts
   - **Model**: Epson TM-T88VI (or your actual printer model)

2. **Tandoor Station** 🔥 `192.168.1.101:9100`
   - **Purpose**: All tandoor-cooked items
   - **Recommended for**: Naan, tandoori chicken, kebabs, etc.
   - **Model**: Star TSP143III (or your actual printer model)

3. **Curry Station** 🍛 `192.168.1.102:9100`
   - **Purpose**: All curry dishes and gravies
   - **Recommended for**: Dal, curry dishes, gravies, rice dishes
   - **Model**: Epson TM-T20III (or your actual printer model)

4. **Appetizer Station** 🥗 `192.168.1.103:9100`
   - **Purpose**: Starters and appetizers
   - **Recommended for**: Samosas, pakoras, salads, cold appetizers
   - **Model**: Star TSP650II (or your actual printer model)

5. **Grill Station** 🔥 `192.168.1.104:9100`
   - **Purpose**: Grilled items and barbecue
   - **Recommended for**: Grilled meats, BBQ items, roasted items
   - **Model**: Epson TM-T82III (or your actual printer model)

6. **Bar/Beverage Station** 🍹 `192.168.1.105:9100`
   - **Purpose**: Drinks and beverages
   - **Recommended for**: Lassi, juices, hot beverages, alcoholic drinks
   - **Model**: Star TSP100 (or your actual printer model)

## 🔧 Step-by-Step Setup Process

### Step 1: Identify Your Physical Printers

First, gather information about your actual printers:

**For each printer, note:**
- **IP Address** (e.g., 192.168.1.150)
- **Port Number** (usually 9100 for most receipt printers)
- **Printer Model** 
- **Location** (which kitchen station it's located at)

### Step 2: Find Printer IP Addresses

**Method A: Check Printer Display/Menu**
1. Most receipt printers have a menu button
2. Navigate to Network Settings or TCP/IP Settings
3. Note down the IP address shown

**Method B: Print Network Configuration**
1. Many printers can print a network status page
2. Hold down the feed button while turning on the printer
3. Look for IP address on the printed page

**Method C: Check Your Router/Network Admin Panel**
1. Log into your router's admin interface
2. Look for "Connected Devices" or "DHCP Client List"
3. Identify printers by their MAC addresses or names

### Step 3: Configure Printer IP Addresses in POS System

1. **Open POS System**
   - Start your POS application
   - Look for the printer icon (🖨️) in the top navigation bar

2. **Access IP Configuration**
   - Click the printer icon
   - Select **"Configure IP Addresses"** from the dropdown menu
   - The IP Configuration dialog will open

3. **Enter Real Printer Information**
   For each printer station:
   - **Replace the default IP** with your actual printer's IP address
   - **Verify the port** (usually 9100)
   - **Update the model name** to match your actual printer

   **Example Configuration:**
   ```
   Main Kitchen Printer: 192.168.1.150:9100  (Your actual main printer)
   Tandoor Station:      192.168.1.151:9100  (Printer near tandoor)
   Curry Station:        192.168.1.152:9100  (Printer at curry station)
   Appetizer Station:    192.168.1.153:9100  (Printer for cold prep)
   Grill Station:        192.168.1.154:9100  (Printer at grill area)
   Bar/Beverage:         192.168.1.155:9100  (Printer at bar)
   ```

4. **Test Connections**
   - Click **"Test Connections"** button
   - Wait for the system to test each printer
   - ✅ Green = Online and working
   - ❌ Red = Not reachable (check IP/network)

5. **Save Configuration**
   - Once all printers show green (online), click **"Save Configuration"**
   - You'll see a success message

### Step 4: Assign Menu Categories to Printers

After configuring IP addresses, assign your menu items to the appropriate printers:

1. **Navigate to Printer Assignments**
   - Go to **Admin Panel** → **Printer Assignments**
   - Or click printer icon → **"Printer Assignments"**

2. **Drag and Drop Assignment**
   - **Left Side**: Your configured printer stations
   - **Right Side**: Menu categories and items
   - **Drag categories** from right to left printer zones

   **Recommended Assignments:**
   ```
   Tandoor Station ← Tandoori items, Naan, Kebabs
   Curry Station ← Curry dishes, Dal, Rice dishes  
   Appetizer Station ← Starters, Salads, Cold items
   Grill Station ← Grilled meats, BBQ items
   Bar/Beverage ← Drinks, Lassi, Beverages
   Main Kitchen ← General items, Coordination
   ```

3. **Multi-Printer Assignment**
   - Some items can go to multiple printers
   - Example: "Chicken Tikka" → Both Tandoor Station AND Main Kitchen

## 🛠️ Troubleshooting Common Issues

### Printer Not Connecting
**Symptoms**: Red "Offline" status in test results

**Solutions:**
1. **Check Network Connection**
   - Ensure printer is connected to same WiFi network
   - Check if printer IP is reachable: `ping 192.168.1.XXX`

2. **Verify IP Address**
   - Double-check the IP address on printer display
   - Make sure no typos in POS configuration

3. **Check Port Number**
   - Most receipt printers use port 9100
   - Some use 515 (LPR) or 631 (IPP)
   - Try different ports if 9100 doesn't work

4. **Firewall Issues**
   - Ensure firewall allows printer communication
   - Check if printer ports are blocked

### Orders Not Printing to Correct Station
**Symptoms**: Orders going to wrong printer or not printing

**Solutions:**
1. **Check Category Assignments**
   - Verify menu categories are assigned to correct printers
   - Use drag-and-drop interface to fix assignments

2. **Test with Sample Order**
   - Create a test order with known items
   - Check which printer receives each item

## 📋 Pre-Setup Checklist

Before starting configuration:

- [ ] All printers are powered on and connected to network
- [ ] You have admin access to POS system
- [ ] You know the IP address of each physical printer
- [ ] All printers are on the same network as POS system
- [ ] You have a plan for which printer goes to which station

## 🎯 Quick Configuration Example

**Scenario**: You have 3 physical printers

**Step 1**: Note your actual printer IPs
- Kitchen Printer A: 192.168.1.200
- Kitchen Printer B: 192.168.1.201  
- Bar Printer: 192.168.1.202

**Step 2**: Configure in POS
- Main Kitchen Printer: 192.168.1.200:9100
- Curry Station: 192.168.1.201:9100
- Bar/Beverage Station: 192.168.1.202:9100
- Set unused stations to same IPs or disable them

**Step 3**: Assign Categories
- All curry items → Curry Station (192.168.1.201)
- All drinks → Bar/Beverage (192.168.1.202)
- Everything else → Main Kitchen (192.168.1.200)

## ⚡ Benefits After Setup

Once configured properly:
- **Automatic Routing**: Orders automatically go to correct kitchen stations
- **Faster Service**: Kitchen staff see only relevant orders
- **Better Organization**: Each station gets their specific items
- **Reduced Errors**: No need to manually sort printed orders
- **Real-time Status**: See which printers are online/offline

## 🔄 Making Changes Later

To modify printer assignments later:
1. Use the IP Configuration dialog to change IP addresses
2. Use the Printer Assignment drag-and-drop interface to reassign categories
3. Test connections after any changes
4. Save configuration to apply changes

Your restaurant POS system is now ready for professional kitchen printer management! 