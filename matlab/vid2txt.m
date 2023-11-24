%% �ű�˵��:��ȡ��Ƶ֡, ������Ƶ֡ת��Ϊtxt�ı���ʽ��hex�ı�(R+G+B+0), ÿһ�����ص���32bit��ʾ
%% ��ȡ��Ƶ�������ص��ļ�
clc
clear all
file_name = "tvb";
txt_path = "../txt/"+file_name+"_uint32.txt"; % txt�ļ�·��
num_frame = 192; % ��ȡ��֡��, ע�ⲻ��������̫��, ���׳���DDR��������
frame_h = 960; %֡�߶ȣ� ��ԭʼ��Ƶ֡�����ø߶�, ���нض���ȥ����
frame_w = 1280; %֡��ȣ� ��ԭʼ��Ƶ֡�����ÿ��, ���нض���ȥ����
obj_v = VideoReader(file_name+".mp4"); % ��ȡ��Ƶ, �õ���Ƶ����
frame = read(obj_v, [1 num_frame]); % ��ȡ֡

imgrgb32 = zeros(num_frame*frame_h*frame_w, 1); %���ٿռ�
imgrgb32 = uint32(imgrgb32);
% ����֡�������ݲ�д�����

% ͬһ�����ص��RGB���ݷ���������������
for f = 1:num_frame %֡����
    for h = 1: frame_h %�б���
        for w = 1: frame_w % �������ص���� 
            % ��RGB������ϳ�32bit����, �������Ӳ��FIFO��
            % R(8bit)+G(8bit)+B(8bit)+0(8bit)
            r = double(frame(h, w, 1, f));  % R����
            g = double(frame(h, w, 2, f));  % G����
            b = double(frame(h, w, 3, f));  % B����
%             r = double(frame((f-1)*frame_h*frame_w*3+(h-1)*frame_w*3+(w-1)*3+1));% R����
%             g = double(frame((f-1)*frame_h*frame_w*3+(h-1)*frame_w*3+(w-1)*3+2));% G����
%             b = double(frame((f-1)*frame_h*frame_w*3+(h-1)*frame_w*3+(w-1)*3+3));% B����
            %�ϳ�32bit���ݲ��浽imgrgb������
            imgrgb32((f-1)*frame_h*frame_w+(h-1)*frame_w+w) = uint32(bitshift(r, 24) + bitshift(g, 16) + bitshift(b, 8));
        end
    end
end
%% ��������д����
% ��32bit���ر���Ϊtxt�ļ�, ʵ��������2������ʽ�༭�ļ�
fid = fopen(txt_path, "w"); %���ļ�
fwrite(fid, imgrgb32, "uint32", "ieee-be");
fclose(fid);
