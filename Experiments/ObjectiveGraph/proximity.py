"""Horizontal circle/rotated-rectangle footprint proximity; not movement or visibility."""
import math

def segment_point(p,a,b):
    v=[b[i]-a[i] for i in range(2)];den=sum(x*x for x in v)
    t=max(0,min(1,sum((p[i]-a[i])*v[i] for i in range(2))/den)) if den else 0
    return [a[i]+t*v[i] for i in range(2)]

def corners(f):
    c,s=math.cos(math.radians(f[3])),math.sin(math.radians(f[3]))
    return [[f[1][0]+x*f[2][0]*c+y*f[2][1]*s,f[1][1]-x*f[2][0]*s+y*f[2][1]*c] for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]]

def nearest_rectangle(p,f):
    c,s=math.cos(math.radians(f[3])),math.sin(math.radians(f[3]));dx,dy=p[0]-f[1][0],p[1]-f[1][1]
    x=max(-f[2][0],min(f[2][0],dx*c-dy*s));y=max(-f[2][1],min(f[2][1],dx*s+dy*c))
    return [f[1][0]+x*c+y*s,f[1][1]-x*s+y*c]

def segment_pair(a,b,c,d):
    cross=lambda u,v:u[0]*v[1]-u[1]*v[0]
    u=[b[i]-a[i] for i in range(2)];v=[d[i]-c[i] for i in range(2)];w=[c[i]-a[i] for i in range(2)];den=cross(u,v)
    if abs(den)>1e-12:
        t,q=cross(w,v)/den,cross(w,u)/den
        if 0<=t<=1 and 0<=q<=1:
            p=[a[i]+t*u[i] for i in range(2)];return p,p
    return min([(a,segment_point(a,c,d)),(b,segment_point(b,c,d)),(segment_point(c,a,b),c),(segment_point(d,a,b),d)],key=lambda pair:math.dist(*pair))

def closest(a,b):
    if a[0]=='circle' and b[0]=='circle':
        x,y=a[1][:2],b[1][:2];d=math.dist(x,y)
        if d<=a[2][0]+b[2][0]:
            p=[x[i]+(y[i]-x[i])*min(a[2][0]/d,1) for i in range(2)] if d else x
            return 0,p,p
        pa=[x[i]+(y[i]-x[i])*a[2][0]/d for i in range(2)];pb=[y[i]+(x[i]-y[i])*b[2][0]/d for i in range(2)]
        return d-a[2][0]-b[2][0],pa,pb
    if a[0]=='rectangle' and b[0]=='circle':
        gap,pb,pa=closest(b,a);return gap,pa,pb
    if a[0]=='circle':
        x=a[1][:2];q=nearest_rectangle(x,b);d=math.dist(x,q)
        if d<=a[2][0]:return 0,q,q
        p=[x[i]+(q[i]-x[i])*a[2][0]/d for i in range(2)];return d-a[2][0],p,q
    ac,bc=corners(a),corners(b)
    for p in ac:
        if math.dist(p,nearest_rectangle(p,b))<1e-8:return 0,p,p
    for p in bc:
        if math.dist(p,nearest_rectangle(p,a))<1e-8:return 0,p,p
    pair=min((segment_pair(ac[i],ac[(i+1)%4],bc[j],bc[(j+1)%4]) for i in range(4) for j in range(4)),key=lambda pair:math.dist(*pair))
    return math.dist(*pair),*pair

def links(sites,maximum=2000):
    result=[]
    for i,a in enumerate(sites):
        for j in range(i+1,len(sites)):
            b=sites[j];fa,fb=a['footprint'],b['footprint']
            radius=lambda f:f[2][0] if f[0]=='circle' else math.hypot(*f[2])
            if math.dist(fa[1][:2],fb[1][:2])-radius(fa)-radius(fb)>maximum:continue
            gap,pa,pb=closest(fa,fb)
            if gap<=maximum:result.append(dict(a=i,b=j,gapM=gap,centerDistanceM=math.dist(a['position'],b['position']),points=[pa,pb],kind='proximity',traversal='unassessed',visibility='unassessed'))
    return result
