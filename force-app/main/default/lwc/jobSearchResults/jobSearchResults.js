import { LightningElement, wire } from 'lwc';
import getJobCategoryValues from '@salesforce/apex/JobSearchResultsController.getJobCategoryValues';

export default class JobSearchResults extends LightningElement {

  // 使用 @wire 从 Apex 获取父子字段联动数据
  @wire(getJobCategoryValues) dependencyMap;
  dependencyMaps =  [
  {
    name: '営業系',
    checked: false,
    subCategories: [
      { name: 'Software Engineer', checked: false, key: '営業系-Software Engineer' },
      { name: 'Data Scientist', checked: false, key: '営業系-Data Scientist' }
    ],
    key: '営業系' // 父类的唯一标识符
  },
  {
    name: '管理部門',
    checked: false,
    subCategories: [
      { name: 'Human Resources', checked: false, key: '管理部門-Human Resources' },
      { name: 'Legal', checked: false, key: '管理部門-Legal' }
    ],
    key: '管理部門' // 父类的唯一标识符
  }
]

  // 获取数据并处理
get jobCategoryData() {
    if (this.dependencyMap.data) {
      return Object.keys(this.dependencyMap.data).map((categoryName) => {
        const category = this.dependencyMap.data[categoryName];
        return {
          name: category.name,
          checked: category.checked, // 父类的 checked 状态
          child: category.child.map(subCategory => ({
            ...subCategory,
            checked: subCategory.checked || false // 子类的 checked 状态
          }))
        };
      });
    }
    return [];
  }

  // 判断数据是否加载中
  get isDataLoading() {
    return !this.dependencyMap.data && !this.dependencyMap.error;
  }

  // 错误消息
  get errorMessage() {
    return this.dependencyMap.error ? `Error: ${this.dependencyMap.error.message}` : '';
  }

  // 父复选框变化
  handleParentChange(event) {
    // 移除焦点
    document.activeElement?.blur();

    const categoryName = event.target.dataset.categoryName;
    const isChecked = event.target.checked;

    console.log('Parent category changed:', categoryName, 'Checked:', isChecked);

    // 更新子类选中状态
    this.updateChildChecked(categoryName, isChecked);
  }

  // 更新子类复选框状态
  updateChildChecked(categoryName, isChecked) {
    console.log('更新子类复选框状态')
    const category = this.jobCategoryData.find(cat => cat.name === categoryName);
    console.log('jobCategoryData',this.jobCategoryData)
    console.log('category',category)
    if (category && category.child) {
      category.child.forEach(subCategory => {
        subCategory.checked = isChecked; // 更新每个子复选框的状态
      });
    }
  }

  // 子复选框变化
  handleChildChange(event) {
    const parentCategoryName = event.target.dataset.parentName;
    const subCategoryName = event.target.dataset.subcategoryName;
    const checked = event.target.checked;

    console.log('Child category changed:', parentCategoryName, subCategoryName, 'Checked:', checked);

    // 更新子类的 checked 状态
    const category = this.jobCategoryData.find(cat => cat.name === parentCategoryName);
    if (category) {
      const subCategory = category.child.find(sub => sub.name === subCategoryName);
      if (subCategory) {
        subCategory.checked = checked;
      }
    }

    // 更新父类的 checked 状态
    this.updateParentChecked(parentCategoryName);
  }

  // 更新父类的 checked 状态
  updateParentChecked(parentCategoryName) {
    const category = this.jobCategoryData.find(cat => cat.name === parentCategoryName);
    if (category) {
      // 检查是否所有子类都被选中
      category.checked = category.child.every(subCategory => subCategory.checked);
    }
  }

  // 搜索按钮点击处理
  handleSearch() {
    console.log('Search button clicked');
  }
  
}