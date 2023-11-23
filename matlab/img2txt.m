clc, clear;
%% �������ݻ�ȡ
file_name = "fisherGirlStatue_1280_960";
img = imread(fullfile("../img/",file_name+".jpg")); %��ȡԭʼ�ļ�
[height, weight, channel] = size(img);  % ��ȡͼƬ��С����
% ��ͼƬͬһ����λ���ϵ�RGBֵ����һ�𹹳�RGB888����
imgrgb = zeros(size(img));  %���ٿռ�
imgrgb = imgrgb(:);  % ת��Ϊ1��
for h=1:height  % ���Uint8��ʽ��RGB��ͨ������
    for w=1:weight
        for c=1:channel
            imgrgb((h-1)*weight*channel+(w-1)*channel+c) = img(h, w, c);
        end
    end
end
%imgrgb = uint8(imgrgb); %ת��ΪUint8��ʽ

%% ���ݴ����뱣��
% ��RGB������ϳ�32bit����, �������Ӳ��FIFO��
% R(8bit)+G(8bit)+B(8bit)+0(8bit)
rgb32b = zeros(height, weight); % ���ٿռ�
rgb32b = rgb32b(:);  % ת��Ϊ1��
for i=1:height*weight
    r = imgrgb((i-1)*3+1);
    g = imgrgb((i-1)*3+2);
    b = imgrgb((i-1)*3+3);
     % λƴ�Ӳ���
    rgb32b(i) = uint32(bitshift(r, 24) + bitshift(g, 16) + bitshift(b, 8));
end
imgrgb = uint8(imgrgb);
rgb32b = uint32(rgb32b); % ת��Ϊ����

% % ��ͨ�����ر���Ϊtxt�ļ�
% txt_path = "../txt/"+file_name+".txt"; % �ļ�·��
% fid = fopen(txt_path, "w");
% fprintf(fid,"%02x",imgrgb);  % ������ļ�
% fclose(fid);

% 32bit���ر���Ϊtxt�ļ�,�Զ����Ƹ�ʽд��
txt_path = "../txt/"+file_name+"_uint32.txt"; % �ļ�·��
fid = fopen(txt_path, "w");
fwrite(fid,rgb32b, "uint32","ieee-be");  % ������ļ�, ���ģʽд��, �����ļ��ɸߵ��Ͷ�����˳��ǡ��ΪRGB0
fclose(fid);

