@echo off
rd /S /Q public
hugo
cd public
git init
git add -A
git commit -m "update blog"
git push -f git@github.com:Expost/expost.github.io.git master

echo 是否要更新hugo blog到git仓库上？是则回车，否则关闭窗口
pause

cd ..
git add *
git commit -m "更新blog"
git push origin master
pause