#!/bin/bash
# 自动生成modulemap脚本
# 接受一个路径list
# 并遍历list所有的framework,然后补全缺失的module.modulemap

# 创建modulemap文件，接收一个后缀为.framework的路经
function execute_map(){

#echo "Processing framework."

    framework=$1
    framework_name=`basename $framework .framework`

    # 确保该路径为framework
    if [[ $framework =~ ".framework\$" ]]; then
        return
    fi

    if [ ! -d $framework/Modules ]; then
        mkdir $framework/Modules
    fi

    # 确保没有已存在的module.modulemap
    if [ -f $framework/Modules/module.modulemap ]; then
        return
    fi
    echo "framework module $framework_name {" >> $framework/Modules/module.modulemap
    if [ -f  $framework/Headers/$framework_name-umbrella.h ]; then
        echo "    umbrella header \"$framework_name-umbrella.h\"" >> $framework/Modules/module.modulemap
    else
        filelist=`ls $framework/Headers`
        for file in $filelist ; do
            echo "    header \"$file\"" >> $framework/Modules/module.modulemap
        done
    fi
    echo "    export *" >> $framework/Modules/module.modulemap
    echo "}" >> $framework/Modules/module.modulemap
}

echo "👾: Append modulemap at once."

for path in $* ; do
    for framework in `find $path -name "*.framework"`; do
        execute_map $framework
    done
done

echo "👾: Append modulemap done."
