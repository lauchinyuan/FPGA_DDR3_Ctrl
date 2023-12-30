%% ��4��ͼƬд��������ַ�ռ�, ��ΪDDR��ͨ�����Ĳ�������
clc, clear;
%% �������ݻ�ȡ
% ͼƬ���б�
file_name_array = ["zzu_640_480",  "szu_640_480", "cloud_640_480","fisherGirlStatue_640_480"];
txt_file_name = "fisherg"; %����Ķ�ͨ��ͼ��txt�ļ���
[void, file_num] = size(file_name_array); % file_numΪͼ���ļ���
% ��ͼƬͬһ����λ���ϵ�RGBֵ����һ�𹹳�RGB888����
for f = 1:file_num
    file_name = file_name_array(f); % ��һ��ȡ�б��е��ļ���
    img = imread(fullfile("../img/",file_name+".jpg")); %��ȡԭʼ�ļ�
    if(f==1) % ��һ��ͼ�� ��ȡͼ���С������ �����ٱ�������ռ�
        [height, width, channel] = size(img);  % ��ȡͼƬ��С����
        imgrgb = zeros(file_num, height, width, channel);  %���ٿռ�
        imgrgb = imgrgb(:);  % ת��Ϊ1��
    end
    for h=1:height  % ���Uint8��ʽ��RGB��ͨ������
        for w=1:width
            for c=1:channel
                imgrgb((f-1)*height*width*channel+(h-1)*width*channel+(w-1)*channel+c) = img(h, w, c);
            end
        end
    end
end

%% ���ݴ����뱣��
% ��RGB������ϳ�32bit����, �������Ӳ��FIFO��
% R(8bit)+G(8bit)+B(8bit)+0(8bit)
rgb32b = zeros(file_num, height, width); % ���ٿռ�
rgb32b = rgb32b(:);  % ת��Ϊ1��
for f=1:file_num % �����ļ�
    for i=1:height*width % �����ļ�������
        r = imgrgb((f-1)*height*width*3+(i-1)*3+1);
        g = imgrgb((f-1)*height*width*3+(i-1)*3+2);
        b = imgrgb((f-1)*height*width*3+(i-1)*3+3);
        % λƴ�Ӳ���
        rgb32b((f-1)*height*width+i) = uint32(bitshift(r, 24) + bitshift(g, 16) + bitshift(b, 8));
    end
end

imgrgb = uint8(imgrgb);
rgb32b = uint32(rgb32b); % ת��Ϊ����


% 32bit���ر���Ϊtxt�ļ�,�Զ����Ƹ�ʽд��
txt_path = "../txt/"+txt_file_name+".txt"; % �ļ�·��
% �ж��ļ��Ƿ����, ������ɾ��
if exist(txt_path,'file')
    delete(txt_path);
end
fid = fopen(txt_path, "w");
fwrite(fid,rgb32b, "uint32","ieee-be");  % ������ļ�, ���ģʽд��, �����ļ��ɸߵ��Ͷ�����˳��ǡ��ΪRGB0
fclose(fid);