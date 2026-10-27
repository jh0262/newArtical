"""Generate publication figures from raw model/result artifacts using Pillow."""
from __future__ import annotations

import csv
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "07_figures"
W, H = 2400, 1500
COLORS = {"ctade": "#0072B2", "index_de": "#D55E00", "random_catalog_de": "#009E73",
          "nsga2_mixed": "#CC79A7", "grid": "#7A7A7A", "light": "#E8EEF4", "dark": "#17324D"}


def font(size, bold=False):
    name = "arialbd.ttf" if bold else "arial.ttf"
    return ImageFont.truetype(str(Path("C:/Windows/Fonts") / name), size)


def canvas():
    return Image.new("RGB", (W, H), "white")


def save(img, name):
    img.save(OUT / name, dpi=(300, 300), optimize=True)


def axes(draw, x0, y0, x1, y1, xlabel, ylabel, title):
    draw.line((x0, y1, x1, y1), fill="black", width=4)
    draw.line((x0, y0, x0, y1), fill="black", width=4)
    draw.text(((x0+x1)//2, y1+145), xlabel, font=font(44), anchor="mm", fill="black")
    draw.text((x0, y0-38), ylabel, font=font(38), anchor="ls", fill="black")
    draw.text(((x0+x1)//2, 70), title, font=font(56, True), anchor="mm", fill=COLORS["dark"])


def scale(v, lo, hi, a, b):
    return a + (float(v)-lo)/(hi-lo)*(b-a)


def workflow():
    img = canvas(); d = ImageDraw.Draw(img)
    d.text((W//2, 90), "Scientific test of solver-selection suitability", font=font(62, True), anchor="mm", fill=COLORS["dark"])
    labels = [
        ("Catalogue coupling", "19 inseparable product tuples"),
        ("Structure diagnosis", "monotonicity + active constraints"),
        ("Exact reduction", "one boundary candidate per row"),
        ("Fallback experiment", "400 / 800 / 1600 evaluations"),
        ("Engineering sensitivity", "identity change vs response scale"),
        ("Scientific inference", "solver follows effective structure"),
    ]
    xs = [310, 900, 1490, 2080, 1490, 900]
    ys = [520, 520, 520, 520, 1050, 1050]
    for i, ((title, sub), x, y) in enumerate(zip(labels, xs, ys)):
        d.rounded_rectangle((x-240, y-130, x+240, y+130), radius=28, fill="#F5F8FB", outline=COLORS["ctade"], width=5)
        d.text((x, y-35), title, font=font(38, True), anchor="mm", fill=COLORS["dark"])
        d.text((x, y+40), sub, font=font(26), anchor="mm", fill="#394B59")
    arrows = [(550,520,660,520),(1140,520,1250,520),(1730,520,1840,520),(2080,650,1730,920),(1250,1050,1140,1050)]
    for x0,y0,x1,y1 in arrows:
        d.line((x0,y0,x1,y1), fill=COLORS["dark"], width=7)
        ang=math.atan2(y1-y0,x1-x0); L=24
        p1=(x1-L*math.cos(ang-0.55),y1-L*math.sin(ang-0.55)); p2=(x1-L*math.cos(ang+0.55),y1-L*math.sin(ang+0.55))
        d.polygon([(x1,y1),p1,p2], fill=COLORS["dark"])
    d.text((W//2, 1370), "Completed experiments test mathematical necessity and mechanism; they do not constitute physical validation.", font=font(38), anchor="mm", fill="#555555")
    save(img, "Fig1_workflow.png")


def catalogue_map():
    rows = list(csv.DictReader((ROOT/"03_model"/"catalog_btkv.csv").open(encoding="utf-8-sig")))
    x = np.array([float(r["nut_mass_kg"])+0.65*float(r["shaft_mass_kg_m"]) for r in rows])
    y = np.array([float(r["K_N_um"]) for r in rows]); ca=np.array([float(r["Ca_kN"]) for r in rows])
    img=canvas(); d=ImageDraw.Draw(img); x0,y0,x1,y1=270,180,2250,1250
    axes(d,x0,y0,x1,y1,"Ball-screw hardware mass (kg)","Catalogue axial stiffness (N/µm)","Manufacturer catalogue design space")
    xmin,xmax=0,16; ymin,ymax=0,1000
    for val in [0,4,8,12,16]:
        px=scale(val,xmin,xmax,x0,x1); d.line((px,y0,px,y1),fill="#E5E5E5",width=2); d.text((px,y1+35),str(val),font=font(30),anchor="ma",fill="black")
    for val in [0,200,400,600,800,1000]:
        py=scale(val,ymin,ymax,y1,y0); d.line((x0,py,x1,py),fill="#E5E5E5",width=2); d.text((x0-25,py),str(val),font=font(30),anchor="rm",fill="black")
    for r,xx,yy,cc in zip(rows,x,y,ca):
        px=scale(xx,xmin,xmax,x0,x1); py=scale(yy,ymin,ymax,y1,y0); radius=14+int(24*cc/ca.max())
        d.ellipse((px-radius,py-radius,px+radius,py+radius),fill=COLORS["ctade"],outline="white",width=3)
        if r["model"] in {"BTK2510V-5.3","BTK3210V-2.6","BTK3210V-5.3","BTK3610V-5.3"}:
            d.text((px+22,py-25),r["model"].replace("BTK", ""),font=font(26,True),fill=COLORS["dark"])
    d.text((x1-10,y0+20),"Bubble area indicates dynamic load rating",font=font(30),anchor="ra",fill="#555")
    save(img,"Fig2_catalogue_map.png")


def oracle_plot():
    data=json.loads((ROOT/"06_results"/"main_30x800_v3_physics"/"oracle_front.json").read_text(encoding="utf-8"))["front"]
    img=canvas(); d=ImageDraw.Draw(img); x0,y0,x1,y1=280,180,2250,1250
    axes(d,x0,y0,x1,y1,"Ball-screw hardware mass (kg)","Worst-scenario axial deformation (µm)","Analytical catalogue Pareto front")
    xmin,xmax=3.5,7.2; ymin,ymax=11,21
    for val in [4,5,6,7]:
        px=scale(val,xmin,xmax,x0,x1); d.line((px,y0,px,y1),fill="#E5E5E5",width=2); d.text((px,y1+35),str(val),font=font(30),anchor="ma",fill="black")
    for val in [12,14,16,18,20]:
        py=scale(val,ymin,ymax,y1,y0); d.line((x0,py,x1,py),fill="#E5E5E5",width=2); d.text((x0-25,py),str(val),font=font(30),anchor="rm",fill="black")
    pts=sorted(data,key=lambda r:r["hardware_mass_kg"])
    coords=[(scale(r["hardware_mass_kg"],xmin,xmax,x0,x1),scale(r["deformation_um"],ymin,ymax,y1,y0)) for r in pts]
    d.line(coords,fill=COLORS["ctade"],width=7)
    for r,(px,py) in zip(pts,coords):
        d.ellipse((px-17,py-17,px+17,py+17),fill=COLORS["ctade"],outline="white",width=3)
        d.text((px+24,py-28),r["model"],font=font(30,True),fill=COLORS["dark"])
    d.text((x0+10,y1+65),"Each point is the analytically minimized deformation for one feasible catalogue tuple.",font=font(30),fill="#555")
    save(img,"Fig3_oracle_front.png")


def boxplot():
    rows=list(csv.DictReader((ROOT/"06_results"/"main_30x800_v3_physics"/"run_metrics.csv").open(encoding="utf-8-sig")))
    methods=["ctade","index_de","nsga2_mixed","random_catalog_de"]; labels=["CTADE","Index-DE","Mixed NSGA-II","Random-catalogue DE"]
    vals={m:np.array([float(r["relative_hypervolume"]) for r in rows if r["method"]==m]) for m in methods}
    img=canvas(); d=ImageDraw.Draw(img); x0,y0,x1,y1=280,180,2250,1250
    axes(d,x0,y0,x1,y1,"Method","Relative hypervolume","Pareto recovery at 800 evaluations (30 paired seeds)")
    ymin,ymax=0.35,1.02
    for val in [0.4,0.6,0.8,1.0]:
        py=scale(val,ymin,ymax,y1,y0); d.line((x0,py,x1,py),fill="#E5E5E5",width=2); d.text((x0-25,py),f"{val:.1f}",font=font(30),anchor="rm",fill="black")
    for j,(m,label) in enumerate(zip(methods,labels)):
        px=x0+(j+1)*(x1-x0)/5; q1,med,q3=np.percentile(vals[m],[25,50,75]); lo,hi=vals[m].min(),vals[m].max()
        d.line((px,scale(lo,ymin,ymax,y1,y0),px,scale(hi,ymin,ymax,y1,y0)),fill=COLORS[m],width=5)
        d.rectangle((px-100,scale(q3,ymin,ymax,y1,y0),px+100,scale(q1,ymin,ymax,y1,y0)),fill="#FFFFFF",outline=COLORS[m],width=7)
        d.line((px-100,scale(med,ymin,ymax,y1,y0),px+100,scale(med,ymin,ymax,y1,y0)),fill=COLORS[m],width=8)
        for v in vals[m]: d.ellipse((px-7,scale(v,ymin,ymax,y1,y0)-7,px+7,scale(v,ymin,ymax,y1,y0)+7),fill=COLORS[m])
        d.text((px,y1+25),label,font=font(31,True),anchor="ma",fill=COLORS["dark"])
    save(img,"Fig4_hypervolume_boxplot.png")


def budget_plot():
    budgets=[400,800,1600]; dirs=["budget_30x400_v3_physics","main_30x800_v3_physics","budget_30x1600_v3_physics"]
    methods=["ctade","index_de","nsga2_mixed","random_catalog_de"]
    img=canvas(); d=ImageDraw.Draw(img); x0,y0,x1,y1=280,180,2250,1250
    axes(d,x0,y0,x1,y1,"Function evaluations","Median relative hypervolume","Budget sensitivity (30 seeds per setting)")
    ymin,ymax=.5,1.01
    for val in [.5,.6,.7,.8,.9,1.0]:
        py=scale(val,ymin,ymax,y1,y0); d.line((x0,py,x1,py),fill="#E5E5E5",width=2); d.text((x0-25,py),f"{val:.1f}",font=font(30),anchor="rm",fill="black")
    for b in budgets:
        px=scale(b,400,1600,x0,x1); d.text((px,y1+35),str(b),font=font(30),anchor="ma",fill="black")
    for m in methods:
        med=[]; q1=[]; q3=[]
        for dd in dirs:
            s=json.loads((ROOT/"06_results"/dd/"summary.json").read_text(encoding="utf-8"))["methods"][m]["relative_hypervolume"]
            med.append(s["median"]);q1.append(s["q1"]);q3.append(s["q3"])
        pts=[]
        for b,md,l,u in zip(budgets,med,q1,q3):
            px=scale(b,400,1600,x0,x1); py=scale(md,ymin,ymax,y1,y0); pts.append((px,py))
            d.line((px,scale(l,ymin,ymax,y1,y0),px,scale(u,ymin,ymax,y1,y0)),fill=COLORS[m],width=5)
            d.ellipse((px-15,py-15,px+15,py+15),fill=COLORS[m])
        d.line(pts,fill=COLORS[m],width=7)
    legend=[("CTADE","ctade"),("Index-DE","index_de"),("Mixed NSGA-II","nsga2_mixed"),("Random-catalogue DE","random_catalog_de")]
    d.rounded_rectangle((1660,180,2240,455),radius=18,fill="white",outline="#CCCCCC",width=2)
    for j,(lab,m) in enumerate(legend):
        yy=230+j*60; d.line((1770,yy,1830,yy),fill=COLORS[m],width=8); d.text((1850,yy),lab,font=font(30),anchor="lm",fill="black")
    save(img,"Fig5_budget_sensitivity.png")


if __name__=="__main__":
    workflow(); catalogue_map(); oracle_plot(); boxplot(); budget_plot()
    print("generated 5 figures")
