import zlib from 'node:zlib';

// Baut eine kleine ZIP-Datei (deflate), wie Bambu Studio sie als .3mf schreibt.
export function makeZip(files) {
  const local = [];
  const central = [];
  let offset = 0;
  for (const [name, content] of Object.entries(files)) {
    const data = Buffer.from(content);
    const comp = zlib.deflateRawSync(data);
    const nameBuf = Buffer.from(name);
    const lh = Buffer.alloc(30);
    lh.writeUInt32LE(0x04034b50, 0);
    lh.writeUInt16LE(20, 4);
    lh.writeUInt16LE(8, 8);
    lh.writeUInt32LE(comp.length, 18);
    lh.writeUInt32LE(data.length, 22);
    lh.writeUInt16LE(nameBuf.length, 26);
    local.push(lh, nameBuf, comp);
    const ch = Buffer.alloc(46);
    ch.writeUInt32LE(0x02014b50, 0);
    ch.writeUInt16LE(20, 4);
    ch.writeUInt16LE(20, 6);
    ch.writeUInt16LE(8, 10);
    ch.writeUInt32LE(comp.length, 20);
    ch.writeUInt32LE(data.length, 24);
    ch.writeUInt16LE(nameBuf.length, 28);
    ch.writeUInt32LE(offset, 42);
    central.push(ch, nameBuf);
    offset += 30 + nameBuf.length + comp.length;
  }
  const cd = Buffer.concat(central);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(Object.keys(files).length, 8);
  end.writeUInt16LE(Object.keys(files).length, 10);
  end.writeUInt32LE(cd.length, 12);
  end.writeUInt32LE(offset, 16);
  return new Uint8Array(Buffer.concat([...local, cd, end]));
}

export const SLICE_INFO = `<?xml version="1.0" encoding="UTF-8"?>
<config>
  <header>
    <header_item key="X-BBL-Client-Type" value="slicer"/>
    <header_item key="X-BBL-Client-Version" value="02.02.01.60"/>
  </header>
  <plate>
    <metadata key="index" value="1"/>
    <metadata key="printer_model_id" value="N2S"/>
    <metadata key="prediction" value="5013"/>
    <metadata key="weight" value="25.36"/>
    <object identify_id="123" name="Halter.stl" skipped="false" />
    <filament id="1" tray_info_idx="GFA00" type="PLA" color="#FFFFFF" used_m="8.37" used_g="24.96" />
    <filament id="3" tray_info_idx="GFA00" type="PLA" color="#000000" used_m="0.13" used_g="0.40" />
    <filament id="4" tray_info_idx="GFG00" type="PETG" color="#FF0000" used_m="0" used_g="0" />
  </plate>
  <plate>
    <metadata key="index" value="2"/>
    <metadata key="prediction" value="600"/>
    <filament id="1" type="PLA" color="#FFFFFF" used_m="1" used_g="3.10" />
  </plate>
</config>`;

export const GCODE_BAMBU = `; HEADER_BLOCK_START
; BambuStudio 02.02.01.60
; model printing time: 2h 19m 23s; total estimated time: 2h 26m 33s
; total layer number: 66
; total filament length [mm] : 13286.53,385.50
; total filament volume [cm^3] : 31957.88,927.23
; total filament weight [g] : 39.63,1.15
; filament_density: 1.24,1.24
; filament_diameter: 1.75,1.75
; max_z_height: 13.20
; HEADER_BLOCK_END

; CONFIG_BLOCK_START
; filament_colour = #00AE42;#FFFFFF
; filament_ids = GFA00;GFA01
; filament_type = PLA;PLA
; CONFIG_BLOCK_END
G28
`;

export const GCODE_PRUSA = `G1 X10
; filament used [mm] = 5000.5
; filament used [g] = 15.2
; total filament used [g] = 15.2
; estimated printing time (normal mode) = 1h 5m 3s
; filament_colour = #FF8000
; filament_type = PETG
`;
