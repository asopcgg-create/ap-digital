export const grades=['Grupa mică','Grupa mijlocie','Grupa mare','Pregătitoare','I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII'];
export type Child={full_name:string;grade:string;class_label:string};
export type Application={id:string;reference:string;full_name:string;email:string;phone:string;children:Child[];status:'draft'|'submitted';created_at:string;updated_at:string;submitted_at:string|null;privacy_version:string};
export type Reconfirmation={id:string;user_id:string;school_year:number;choice:'continuing'|'updated'|'leaving';children:Child[];created_at:string;reviewed_at:string|null;review_reference:string|null};
export const emptyChild=():Child=>({full_name:'',grade:'',class_label:''});
