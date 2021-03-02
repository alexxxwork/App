import styles from './styles';
import variables from './variables';
import themeColors from './themes/default';

const defaultWrapperStyle = {
    flex: 1,
    backgroundColor: themeColors.componentBG,
};

const miniWrapperStyle = [
    styles.flexRow,
    defaultWrapperStyle,
    {
        borderRadius: variables.componentBorderRadiusNormal,
        borderWidth: 1,
        borderColor: themeColors.border,
    },
];

const bigWrapperStyle = [
    styles.flexColumn,
    defaultWrapperStyle,
];

/**
 * Generate the wrapper styles for the ReportActionContextMenu.
 *
 * @param {Boolean} isMini
 * @returns {Array}
 */
function getReportActionContextMenuStyles(isMini) {
    return isMini ? miniWrapperStyle : bigWrapperStyle;
}

export default getReportActionContextMenuStyles;
