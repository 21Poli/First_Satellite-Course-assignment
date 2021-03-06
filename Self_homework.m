receiver=importdata('D:\PolyU\Courses\Satellite communication and navigation\Assignment1\Assignment\Data\rcvr.dat');
ephemeris=importdata('D:\PolyU\Courses\Satellite communication and navigation\Assignment1\Assignment\Data\eph.dat');
ephemeris=ephemeris([2:end,1],:);
c=299792458.0;%speed of light
wedot=7.2921151467e-5;%value of earth's rotation rate
mu=3.986005e+14;% value of earth's universal gravitation constant
F=-4.442807633e-10;%relativistic correction term constant
tow=ephemeris(:,1);%receiver time of weeks
pr=receiver(:,3);%pseudorange
toe=ephemeris(:,4);%reference time of ephemeris parameters(s)
e=ephemeris(:,9);%eccentricity
sqrta=ephemeris(:,10);%square root of semi-major axis
a=sqrta.^2;%semi-major axis
dn=ephemeris(:,11);%mean motion correction(r/s)
m0=ephemeris(:,12);%mean anomaly at rerefence time(r)
w=ephemeris(:,13); % argument of perigee(r)
omg0=ephemeris(:,14);%right ascention(r)
i0=ephemeris(:,15);%inclination angle at reference time(r)
odot=ephemeris(:,16);%rate of right ascention(r/s)
idot=ephemeris(:,17);%rate of inclination angle(r/s)
cus=ephemeris(:,18);%arugment of latitude correction,sine(r)
cuc=ephemeris(:,19);%argument of latitude correction, cosine(r)
cis=ephemeris(:,20);%inclination correction,sine(r)
cic=ephemeris(:,21);%inclination correction,cosine(r)
crs=ephemeris(:,22);%radius correction,sine(m)
crc=ephemeris(:,23);%radius correction,cosine(m)
%***************calculate the positions of satellites
%t=440992;
tk=tow-toe-pr./c;%8*1
n0=sqrt(mu./a.^3);%mean motion,8*1
n=n0+dn;%mean motion after correction,8*1
mk=m0+n.*tk;%mean anomaly mk,8*1
for i=1:8
    if mk(i)<0
        mk(i)=mk(i)+2*pi;
    else
        if mk(i)>2*pi
            mk(i)=mk(i)-2*pi;
        end
    end
    
end 
%E eccentric anomaly; M=E-e*sinE,E=M+e*sinE;
for i=1:8 
    E_old(i)=mk(i);%supposed initial value
    E_new(i)=mk(i)+e(i).*sin(E_old(i));
    while abs(E_new(i) - E_old(i))>1e-8
        E_old(i)=E_new(i);
        E_new(i)=mk(i)+e(i).*sin(E_old(i));
    end
end
Ek=E_new;
Ek=Ek';%8*1
%true anomaly
for i=1:8
    sinnuk(i)=sqrt(1-e(i).^2).*sin(Ek(i))./(1-e(i).*cos(Ek(i)));
end
for i=1:8
    cosnuk(i)=(cos(Ek(i))-e(i))./(1-e(i).*cos(Ek(i)));
end
nuk=atan2(sinnuk,cosnuk);
% true anomaly + argument of perigee
nuk=nuk';
phi_k=nuk+w;
% correction for uk,rk,ik
delta_uk=cus.*sin(2*phi_k)+cuc.*cos(2*phi_k);
delta_rk=crs.*sin(2*phi_k)+crc.*cos(2*phi_k);
delta_ik=cis.*sin(2*phi_k)+cic.*cos(2*phi_k);
uk=phi_k+delta_uk;
rk=a.*(1-e.*cos(Ek)) + delta_rk;
ik=i0+idot.*tk+delta_ik;
% convert into WGS-84 coordinate
xpk=rk.*cos(uk);
ypk=rk.*sin(uk);
omegk=omg0+(odot-wedot).*tk-wedot.*toe;
xk=xpk.*cos(omegk)-ypk.*cos(ik).*sin(omegk);
yk=xpk.*sin(omegk)+ypk.*cos(ik).*cos(omegk);
zk=ypk.*sin(ik);
%that's the end of determing the positions of satellites
% determine the broadcast satellite clock error,
% delta_ts=af0+af1(t-toc)+af2(t-toc).^2+Fe(sqrta)sin(Ek)
toc=ephemeris(:,3);%reference time of clock parameters(s)
af0=ephemeris(:,5);%clock correction coefficient-group delay(s)
af1=ephemeris(:,6);%clock correction coefficient(s/s)
af2=ephemeris(:,7);%clock correction coefficients(s/s/s)
delta_ts=af0+af1.*(tow-toc)+af2.*(tow-toc).^2+F.*e.*sqrta.*sin(Ek);
%linearization

%pesudorange + satellite clock error delay
pr_new=pr+c.*delta_ts;
xu0_old=-2694685.473;
yu0_old=-4293642.366;
zu0_old=3857878.924;
%xu0_old=-2;
%yu0_old=-4;
%zu0_old=3;%initial position of satellite for iteration
delt0_old=0;%initial clock bias
x0_old=[xu0_old,yu0_old,zu0_old,delt0_old]';%approximated value,4*1
p0=((xk-xu0_old).^2+(yk-yu0_old).^2 + (zk-zu0_old).^2).^0.5;%approximate range,8*1;
del_p0=pr_new-p0;%difference between range;8*1;
ax0=(xu0_old-xk)./((xk-xu0_old).^2+(yk-yu0_old).^2 + (zk-zu0_old).^2).^0.5;
ay0=(yu0_old-yk)./((xk-xu0_old).^2+(yk-yu0_old).^2 + (zk-zu0_old).^2).^0.5;
az0=(zu0_old-zk)./((xk-xu0_old).^2+(yk-yu0_old).^2 + (zk-zu0_old).^2).^0.5;%gradient
one=c.*ones(8,1);
H=[ax0,ay0,az0,one];%8*4,range in column;gradient + c
delta_x=H\del_p0;%4*1
%delta_x=(H'*H)^(-1)*H'*del_p0; %there may be singular value
cycle_n=0;
eps=1e-4;
%while norm(delta_x)>1e-6
while delta_x(1)>eps || delta_x(2)>eps || delta_x(3)>eps || delta_x(4) > eps
    cycle_n=cycle_n+1;
    x0_new=x0_old+delta_x;%4*1;
    p0=((xk-x0_new(1,:)).^2+(yk-x0_new(2,:)).^2 + (zk-x0_new(3,:)).^2).^0.5+c.*x0_new(4,:);%approximate range
    del_p0=pr_new-p0;%difference between range
    ax0_new=(x0_new(1,:)-xk)./((xk-x0_new(1,:)).^2+(yk-x0_new(2,:)).^2 + (zk-x0_new(3,:)).^2).^0.5;
    ay0_new=(x0_new(2,:)-yk)./((xk-x0_new(1,:)).^2+(yk-x0_new(2,:)).^2 + (zk-x0_new(3,:)).^2).^0.5;
    az0_new=(x0_new(3,:)-zk)./((xk-x0_new(1,:)).^2+(yk-x0_new(2,:)).^2 + (zk-x0_new(3,:)).^2).^0.5;
    %gradient
    H=[ax0_new,ay0_new,az0_new,one];
    delta_x=H\del_p0;
    %delta_x=(H'*H)^(-1)*H'*del_p0;%there may be singular value
    x0_old=x0_new;
end
