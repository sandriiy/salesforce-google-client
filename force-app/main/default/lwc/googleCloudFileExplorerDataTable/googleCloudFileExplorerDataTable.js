import LightningDatatable from 'lightning/datatable';
import fileTitleTemplate from './fileTitle.html';
import userLinkTemplate from './userLink.html';

export default class GoogleCloudFileExplorerDataTable extends LightningDatatable {
	static customTypes = {
		fileTitle: {
			template: fileTitleTemplate,
			standardCellLayout: true,
			typeAttributes: ['label', 'title', 'rowId']
		},
		userLink: {
			template: userLinkTemplate,
			standardCellLayout: true,
			typeAttributes: ['label', 'userId']
		}
	};
}