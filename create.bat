@echo off
rd /S /Q public
hugo
cd public
git init
git add -A
git commit -m "update blog"
git push -f git@github.com:Expost/expost.github.io.git master

echo �Ƿ�Ҫ����hugo blog��git�ֿ��ϣ�����س�������رմ���
pause

cd ..
git add *
git commit -m "����blog"
git push origin master
pause