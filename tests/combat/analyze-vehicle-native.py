"""Build the stock damage calibration from collision-validated native observations."""
import argparse, ast, collections, json, re
from pathlib import Path

def rows(path, marker):
    result=[]
    for line in path.read_text(errors="replace").splitlines():
        if marker not in line: continue
        raw=line.split(marker,1)[1].strip().removesuffix('"').replace('""','"')
        raw=re.sub(r"\btrue\b","True",re.sub(r"\bfalse\b","False",raw))
        result.append(ast.literal_eval(raw))
    return result

def main():
    p=argparse.ArgumentParser();p.add_argument("rpt",type=Path);p.add_argument("--blast",type=Path,required=True);p.add_argument("--output",type=Path,required=True);p.add_argument("--source",type=Path,required=True);a=p.parse_args()
    direct=rows(a.rpt,"[IVCS NATIVE VEHICLE] "); blast=rows(a.blast,"[IVCS NATIVE VEHICLE] ")
    rays=rows(a.rpt,"[IVCS NATIVE RAY] ")
    assert rays and all(r[3] for r in rays), "Every direct observation must intersect the target geometry."
    grouped=collections.defaultdict(list)
    for r in direct:
        if r[1]!="1Rnd_HE_Grenade_shell": grouped[tuple(r[:2])].append(r)
    for r in blast: grouped[tuple(r[:2])].append(r)
    basis={"C_Offroad_01_F":[30,4],"O_MRAP_02_F":[200,5],"O_APC_Wheeled_02_rcws_v2_F":[270,5],"O_MBT_02_cannon_F":[850,6]}
    by_vehicle=collections.defaultdict(list); measurements=[]
    for (vehicle,mag), values in sorted(grouped.items()):
        assert len(values)==3,(vehicle,mag,len(values))
        samples=[[r[3],r[5]] for r in values]
        by_vehicle[vehicle].append([mag,[values[0][7],15,samples]])
        measurements.append(dict(vehicle=vehicle,magazine=mag,overall=[r[3] for r in values],alive=[r[4] for r in values],components=[r[5] for r in values]))
    table=[[v,basis[v]+[entries]] for v,entries in sorted(by_vehicle.items())]
    a.source.write_bytes(("// Generated from native Arma observations; see docs/vehicle-combat-results/native-calibration.json.\r\n"+json.dumps(table,indent=2).replace("\n","\r\n")+"\r\n").encode())
    a.output.write_text(json.dumps(dict(native_rpt=str(a.rpt),blast_rpt=str(a.blast),reference_range_m=15,verified_direct_rays=len(rays),pairs=len(measurements),samples=sum(len(m["overall"]) for m in measurements),measurements=measurements,limitations=["Frontal stationary hull impacts and near-vehicle armed blasts; three samples per pair.","Single-hit calibration does not reproduce all cumulative/native thermal, ERA, directional or crew-injury behavior.","Only matching stock vehicle armor/structural and projectile hit settings use this table; other classes use the configuration fallback."]),indent=2)+"\n")
    print(f"Generated {len(measurements)} pairs / {sum(len(m['overall']) for m in measurements)} native samples; {len(rays)} collision rays verified.")
if __name__=="__main__": main()
