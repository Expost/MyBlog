@echo off
rd /S /Q public
local_hugo
cd public
git init
git add -A
git commit -m "update blog"
git push -f git@github.com:Expost/expost.github.io.git master

echo �Ƿ�Ҫ����hugo blog��git�ֿ��ϣ�����س�������رմ���
pause

cd ..
git add *
set /p input=������Ҫgit�ύʱ����Ϣ��
git commit -m %input%
git push origin master
pause